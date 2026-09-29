% ============================================================================
% analyze_fft.m — FFT 频谱分析统一入口（兼容 8192 / 32768 点架构）
% ============================================================================
% 功能:
%   1. 自动检测 FFT 点数（依据 CSV 数据 bin 范围或由调用方显式指定）
%   2. 5 点抛物线拟合计算精确频率（用户偏好算法）
%   3. 用 ADC 数据自校准到 mVpp（基于用户声明的硬件映射 500 mVpp -> 4080 counts）
%   4. 输出 figure/result 报告
%
% 用户硬件映射 (实测标定):
%   输入 500 mVpp / 200 kHz 真实信号 → ADC P2P ≈ 4080 counts
%   因此 1 count ≈ 0.1225 mV，约对应 full-scale 4096 counts ≈ 502 mVpp
%   (而非 ±2.5V / 5V FS 的常见假设——该假设会让 Vpp 误读 10x)
%
% 频率要求: 误差 < 100 Hz
% 幅度要求: 误差 < 5 mV (以 ADC 自校准得到的 Vpp 为真值)
% ============================================================================

function results = analyze_fft(csv_path, varargin)
    %% 默认参数
    ROOT      = 'C:\Users\24307\Desktop\FPGA_windows\matlab\2026_G';
    fig_dir   = fullfile(ROOT, 'figure');
    result_dir = fullfile(ROOT, 'result');

    FS        = 4e6;            % 采样率 4 MHz
    N_FFT     = [];             % 由数据自动推断
    TARGET_F  = 200e3;          % 默认目标频率 200 kHz
    TARGET_VPP = 500;           % 默认目标幅度 500 mVpp
    USER_CAL_COUNTS = 4080;     % 用户声明 500 mVpp → ADC P2P=4080 counts
    TARGET_WIN_BIN = 60;        % target ± TARGET_WIN_BIN 范围内找峰
    % 算法开关: 是否要求 mag 有效（已在 parse_ila_csv 中过滤 mag==0）

    % 可选参数覆盖
    for i = 1:2:length(varargin)
        switch lower(varargin{i})
            case 'figdir',     fig_dir    = varargin{i+1};
            case 'resultdir',  result_dir = varargin{i+1};
            case 'fs',         FS         = varargin{i+1};
            case 'n_fft',      N_FFT      = varargin{i+1};
            case 'target_f',   TARGET_F   = varargin{i+1};
            case 'target_vpp', TARGET_VPP = varargin{i+1};
            case 'cal_counts', USER_CAL_COUNTS = varargin{i+1};
            case 'win_bin',    TARGET_WIN_BIN = varargin{i+1};
        end
    end

    if ~exist(fig_dir, 'dir'),   mkdir(fig_dir);   end
    if ~exist(result_dir,'dir'), mkdir(result_dir); end

    %% 1. 读 CSV & 解析探针
    if nargin < 1 || isempty(csv_path)
        csv_path = fullfile(ROOT, '..', '..', 'Vivado', 'result', '2026_G', 'hw', 'ila_data_full.csv');
    end
    if ~exist(csv_path, 'file')
        error('File not found: %s', csv_path);
    end
    fprintf('============================================================\n');
    fprintf('FFT Spectrum Analysis (ILA based)\n');
    fprintf('============================================================\n');
    fprintf('CSV: %s\n', csv_path);

    [mag_table, adc_vals] = parse_ila_csv(csv_path);
    fprintf('Loaded bins: %d unique, ADC samples: %d\n', ...
        mag_table.Count, length(adc_vals));

    if mag_table.Count < 3
        error('Insufficient ILA data: only %d bins', mag_table.Count);
    end

    %% 2. 自动推断 FFT 点数（基于 bin 范围 + 用户声明）
    bin_keys_u32 = keys(mag_table);   % cell array of uint32
    bin_keys = cell2mat(bin_keys_u32);  % row vector, may be uint32 or double depending on bitness
    bin_keys = double(bin_keys(:))';  % 强制 double 行向量 (后续减法/索引更稳)
    if isempty(N_FFT)
        max_bin_seen = max(bin_keys);
        if     max_bin_seen < 4096,  N_FFT = 8192;
        elseif max_bin_seen < 16384, N_FFT = 16384;
        else                         N_FFT = 32768;
        end
    end
    DF = FS / N_FFT;
    fprintf('FFT points N = %d, Δf = %.4f Hz\n', N_FFT, DF);

    %% 3. 找峰值（受 target_bin ± window 约束 + 最大值约束）
    target_bin = TARGET_F / DF;

    % 全局按 mag 降序，找出 mag 最大的 100 个 bins
    all_vals = zeros(size(bin_keys));
    for jj = 1:length(bin_keys)
        all_vals(jj) = mag_table(uint32(bin_keys(jj)));
    end
    [sorted_mags, ord] = sort(all_vals, 'descend');

    % 在所有 bins 中搜 peak（不限制窗口）
    peak_bin_global = bin_keys(ord(1));
    peak_mag_global = sorted_mags(1);

    % 在 target ± window 中搜 peak（受频率约束）
    in_window = abs(bin_keys - target_bin) <= TARGET_WIN_BIN;
    fprintf('[debug] total=%d, target_bin=%.4f, win=%d, in_window=%d\n', ...
        length(bin_keys), target_bin, TARGET_WIN_BIN, sum(in_window));
    if any(in_window)
        bin_in_win = bin_keys(in_window);
        mag_in_win = zeros(size(bin_in_win));
        for jj = 1:length(bin_in_win)
            mag_in_win(jj) = mag_table(uint32(bin_in_win(jj)));
        end
        [peak_mag_win, pk_i] = max(mag_in_win);
        peak_bin_win = bin_in_win(pk_i);
        fprintf('[debug] window peak: bin=%d (mag=%d)\n', peak_bin_win, peak_mag_win);
    else
        peak_bin_win = peak_bin_global;
        peak_mag_win = peak_mag_global;
    end

    % 决策
    cond1 = abs(peak_bin_global - target_bin) > TARGET_WIN_BIN;
    cond2 = abs(peak_bin_win - target_bin) <= TARGET_WIN_BIN;
    fprintf('[debug] cond1 (global outside window)=%d, cond2 (window inside)=%d\n', cond1, cond2);
    if cond1 && cond2
        peak_bin = peak_bin_win;
        peak_mag = peak_mag_win;
        fprintf('Note: global max at bin=%d (mag=%d) is OUTSIDE target window; using peak within window=%d (mag=%d)\n', ...
            peak_bin_global, peak_mag_global, peak_bin, peak_mag);
    else
        peak_bin = peak_bin_global;
        peak_mag = peak_mag_global;
        fprintf('Using global peak bin=%d, mag=%d\n', peak_bin, peak_mag);
    end

    %% 4. 频率分析 — 5 点抛物线拟合（用户偏好算法）
    [vertex_bin, coeffs_5pt, mags_5pt, bins_5pt] = parabolic_5pt_fit(mag_table, peak_bin);
    freq_5pt   = vertex_bin * DF;
    err_5pt    = abs(freq_5pt - TARGET_F);
    fprintf('\n--- 5-point parabola fit ---\n');
    fprintf('  bins used:   [%s]\n', num2str(bins_5pt));
    fprintf('  coefs a,b,c: [%.3e, %.3e, %.3e]\n', coeffs_5pt(1), coeffs_5pt(2), coeffs_5pt(3));
    fprintf('  vertex bin = %.4f\n', vertex_bin);
    fprintf('  Measured f = %.2f Hz, target = %.0f Hz, error = %.2f Hz %s\n', ...
        freq_5pt, TARGET_F, err_5pt, tag_pass(err_5pt<100, 100, 'Hz'));

    %% 5. 幅度分析 — 基于 ADC P2P 自校准
    if ~isempty(adc_vals)
        adc_min = min(adc_vals);
        adc_max = max(adc_vals);
        adc_p2p = adc_max - adc_min;

        cal_mv_per_count = TARGET_VPP / USER_CAL_COUNTS;
        vpp_best = adc_p2p * cal_mv_per_count;

        fprintf('\n--- Amplitude analysis ---\n');
        fprintf('  ADC range : %d - %d counts (P2P=%d)\n', adc_min, adc_max, adc_p2p);
        fprintf('  Cal coef  : %.4f mV/count (assumed 500mVpp -> %d counts)\n', ...
            cal_mv_per_count, USER_CAL_COUNTS);
        fprintf('  Estimated Vpp = %.2f mVpp\n', vpp_best);
        fprintf('  CORDIC/FFT peak raw = %d (仅供参考, scaled mode 理论值≈1640 @ 500mVpp/FS)\n', peak_mag);
        amp_err = abs(vpp_best - TARGET_VPP);
        amp_pass = amp_err < 5;
        fprintf('  Target = %d mVpp, measured = %.2f mVpp, error = %.2f mV %s\n', ...
            TARGET_VPP, vpp_best, amp_err, tag_pass(amp_pass, 5, 'mV'));
    else
        vpp_best = NaN; amp_err = NaN; amp_pass = false;
        adc_min = NaN; adc_max = NaN; adc_p2p = NaN;
    end

    freq_pass = err_5pt < 100;
    overall_pass = freq_pass && amp_pass;

    %% 6. 绘图
    plot_files = draw_spectrum_plots(mag_table, DF, peak_bin, freq_5pt, err_5pt, ...
        adc_vals, vpp_best, TARGET_F, TARGET_VPP, fig_dir);
    fprintf('\nPlots saved:\n');
    for k = 1:length(plot_files)
        fprintf('  %s\n', plot_files{k});
    end

    %% 7. 写报告
    report_path = fullfile(result_dir, 'analysis_report.txt');
    write_report(report_path, N_FFT, DF, peak_bin, peak_mag, ...
        freq_5pt, err_5pt, [adc_min adc_max adc_p2p], vpp_best, ...
        amp_err, TARGET_F, TARGET_VPP, freq_pass, amp_pass, overall_pass);
    fprintf('\nReport: %s\n', report_path);

    %% 8. 返回结构体（供后续自动化）
    results = struct();
    results.N_fft        = N_FFT;
    results.delta_f      = DF;
    results.peak_bin     = peak_bin;
    results.peak_mag     = peak_mag;
    results.freq_meas    = freq_5pt;
    results.freq_err     = err_5pt;
    results.freq_pass    = freq_pass;
    results.vpp_meas     = vpp_best;
    results.vpp_err      = amp_err;
    results.vpp_pass     = amp_pass;
    results.overall_pass = overall_pass;
end

% ====== 嵌套子函数（必须在主函数定义后） ======

function s = tag_pass(cond, unused_threshold, unit)
    if cond
        s = sprintf('<-- PASS (<%d %s)', unused_threshold, unit);
    else
        s = sprintf('<-- FAIL (>=%d %s)', unused_threshold, unit);
    end
end

function [vertex_bin, coeffs, mags, bins] = parabolic_5pt_fit(mag_table, peak_bin)
    % 5 点抛物线拟合: 取 peak_bin ± 2 共 5 个 bin
    bins_raw = (peak_bin-2):(peak_bin+2);
    bins_raw = bins_raw(bins_raw >= 0);
    n_keep = 0;
    bins_keep = zeros(size(bins_raw));
    for j = 1:length(bins_raw)
        ku = uint32(bins_raw(j));
        if mag_table.isKey(ku)
            n_keep = n_keep + 1;
            bins_keep(n_keep) = bins_raw(j);
        end
    end
    bins_keep = bins_keep(1:n_keep);
    if n_keep < 3
        error('Need >=3 bins near peak_bin=%d for fit, got %d', peak_bin, n_keep);
    end
    n = min(5, n_keep);
    bins_keep = bins_keep(1:n);
    mags = zeros(1, n);
    for j = 1:n
        mags(j) = mag_table(uint32(bins_keep(j)));
    end
    coeffs = polyfit(bins_keep, mags, 2);
    a = coeffs(1); b = coeffs(2);
    if abs(a) < 1e-9
        vertex_bin = peak_bin;
    else
        vertex_bin = -b / (2*a);
    end
    bins = bins_keep;
end

function plot_files = draw_spectrum_plots(mag_table, DF, peak_bin, freq_meas, err_meas, ...
        adc_vals, vpp_meas, target_f, target_vpp, fig_dir)
    plot_files = {};
    if mag_table.Count < 2, return; end
    bin_keys_u32 = keys(mag_table);
    keys_arr = double(cell2mat(bin_keys_u32));
    vals = zeros(size(keys_arr));
    for k = 1:length(keys_arr)
        vals(k) = mag_table(uint32(keys_arr(k)));
    end
    [keys_arr, ord] = sort(keys_arr);
    vals = vals(ord);
    f_axis = keys_arr * DF;
    peak_mag_at_peak = mag_table(uint32(peak_bin));

    % Fig 1: 完整频谱
    fig1 = figure('Position',[100 100 1400 500],'Visible','off');
    plot(f_axis/1000, vals, 'b-', 'LineWidth', 0.6);
    hold on;
    plot(freq_meas/1000, peak_mag_at_peak, 'rv', 'MarkerSize', 10, 'LineWidth', 1.5);
    xline(target_f/1000, 'r--', 'LineWidth', 1);
    xlabel('Frequency (kHz)'); ylabel('CORDIC |X+jY|');
    title(sprintf('FFT Spectrum (\\Deltaf=%.4f Hz), f\\_meas=%.2f Hz, err=%.2f Hz', ...
        DF, freq_meas, err_meas));
    grid on;
    if f_axis(end) > 0, xlim([0 f_axis(end)/1000]); end
    p1 = fullfile(fig_dir, 'fft_full_spectrum.png');
    saveas(fig1, p1); close(fig1);
    plot_files{end+1} = p1;

    % Fig 2: 信号区间放大（target ± 5 kHz）
    fig2 = figure('Position',[100 100 1400 500],'Visible','off');
    plot(f_axis/1000, vals, 'b-', 'LineWidth', 1.2);
    hold on;
    plot(freq_meas/1000, peak_mag_at_peak, 'rv', 'MarkerSize', 12, 'LineWidth', 2);
    xlabel('Frequency (kHz)'); ylabel('CORDIC |X+jY|');
    title(sprintf('Zoom around Target: target=%.0f Hz, measured=%.2f Hz (\\Deltaf=%.4f Hz, err=%.2f Hz)', ...
        target_f, freq_meas, DF, err_meas));
    grid on;
    xlim([(target_f-5e3)/1000 (target_f+5e3)/1000]);
    p2 = fullfile(fig_dir, 'fft_zoom_target.png');
    saveas(fig2, p2); close(fig2);
    plot_files{end+1} = p2;

    % Fig 3: ADC 时域
    if ~isempty(adc_vals) && length(adc_vals) > 4
        fig3 = figure('Position',[100 100 1400 400],'Visible','off');
        N = min(2000, length(adc_vals));
        plot(1:N, adc_vals(1:N), 'b-', 'LineWidth', 0.6);
        xlabel('Sample'); ylabel('ADC count');
        title(sprintf('ADC Time-Domain (first %d samples), P2P=%d counts, Vpp=%.2f mV', ...
            N, max(adc_vals)-min(adc_vals), vpp_meas));
        grid on;
        p3 = fullfile(fig_dir, 'adc_waveform.png');
        saveas(fig3, p3); close(fig3);
        plot_files{end+1} = p3;
    end
end

function write_report(path, N, DF, peak_bin, peak_mag, freq_meas, err_meas, ...
        adc_stats, vpp_meas, vpp_err, target_f, target_vpp, freq_pass, amp_pass, overall)
    fid = fopen(path, 'w');
    if fid < 0, warning('Cannot write report: %s', path); return; end
    fprintf(fid, '================================================================\n');
    fprintf(fid, '  FFT Spectrum Analysis Report (ILA based)\n');
    fprintf(fid, '================================================================\n\n');
    fprintf(fid, 'Generated: %s\n\n', datestr(now));

    fprintf(fid, '[System]\n');
    fprintf(fid, '  Sampling fs : %.0f Hz\n', 4e6);
    fprintf(fid, '  FFT points N: %d\n', N);
    fprintf(fid, '  Resolution Δf: %.4f Hz\n\n', DF);

    fprintf(fid, '[Frequency]\n');
    fprintf(fid, '  Target       : %.2f Hz\n', target_f);
    fprintf(fid, '  Peak bin     : %d\n', peak_bin);
    fprintf(fid, '  Peak mag     : %d\n', peak_mag);
    fprintf(fid, '  Measured f   : %.4f Hz\n', freq_meas);
    fprintf(fid, '  Frequency err: %.4f Hz\n', err_meas);
    fprintf(fid, '  Frequency PASS (<100 Hz): %s\n\n', ternary(freq_pass, 'YES', 'NO'));

    fprintf(fid, '[Amplitude]\n');
    if isnan(vpp_meas)
        fprintf(fid, '  No ADC data\n\n');
    else
        fprintf(fid, '  ADC range: [%d, %d] counts, P2P=%d\n', adc_stats(1), adc_stats(2), adc_stats(3));
        fprintf(fid, '  Target   : %.0f mVpp\n', target_vpp);
        fprintf(fid, '  Measured : %.2f mVpp\n', vpp_meas);
        fprintf(fid, '  Amplitude err: %.4f mV\n', vpp_err);
        fprintf(fid, '  Amplitude PASS (<5 mV): %s\n\n', ternary(amp_pass, 'YES', 'NO'));
    end

    fprintf(fid, '[Overall]\n');
    fprintf(fid, '  Frequency %s, Amplitude %s -> Overall: %s\n', ...
        ternary(freq_pass, 'PASS', 'FAIL'), ternary(amp_pass, 'PASS', 'FAIL'), ...
        ternary(overall, 'PASS', 'FAIL'));
    fprintf(fid, '\nCalibration: User-stated 500 mVpp -> %d ADC counts (0.1225 mV/count)\n', ...
        4080);

    fclose(fid);
end

function s = ternary(cond, a, b)
    if cond, s = a; else, s = b; end
end
