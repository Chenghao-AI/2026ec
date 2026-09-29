% analyze_multi.m
% 多峰频谱分析 (mixed signal)
%
% 核心改进 (相对 analyze_precise.m):
%   1) 自动检测所有频谱峰 (不依赖 target frequency)
%   2) 每个峰独立做 5 点抛物线 + 加权高斯拟合
%   3) 独立校准幅度
%   4) 输出全频段频谱图 + 局部放大图
%
% 依赖: CSV 列格式 [mag_dec, bin_dec, valid_hex, adc_hex]
% 假设: ADC = AD9226 ±5V FS -> 1 signed LSB = 5000/2048 = 2.441 mV
%       ila_probe_adc 是 signed 12-bit (已经过 MSB 取反 = 2's complement)

clear; clc; close all;

% ---------- 固定参数 ----------
N_FFT = 8192;
FS    = 4e6;
DF    = FS / N_FFT;        % 488.28125 Hz/bin

% ADC 校准 (AD9226 ±5V 输入 -> 1 signed LSB = 2.441 mV)
FS_MV = 5000;
ADC_RANGE = 4096;
ADC_LSB_MV = FS_MV / (ADC_RANGE/2);
LINK_GAIN = 1.22;          % 100 kHz/50 mV 标定结果

FIG_DIR = 'C:\Users\24307\Desktop\FPGA_windows\matlab\2026_G\figure';
if ~isfolder(FIG_DIR), mkdir(FIG_DIR); end

CODE_DIR = 'C:\Users\24307\Desktop\FPGA_windows\matlab\2026_G\code';
addpath(genpath(CODE_DIR));

% ---------- 峰检测参数 ----------
PEAK_MIN_RATIO  = 0.05;    % 峰幅 > 主峰 5% 才算峰 (允许大幅差的多峰, 比如 1:5)
PEAK_MIN_HEIGHT = 0.3;     % 峰幅 > 0.3 mV 才算有效峰
PEAK_MIN_DIST   = 8;       % 两个峰至少相距 8 bin
NOISE_FLOOR     = 0.05;    % 噪声底限 (mV)
% Verilog 偏置修正:
%   FFT 是 8192 点 (NFFT_MAX=13), Δf = 488.28 Hz/bin
%   BinSelect 输入 = bin_cnt + 200 (verilog 端偏置, 让低频 bin 0..199 完整显示)
%   ILA probe 是 11-bit (mod 2048), 不影响 <2047 的 bin
%   MATLAB 解析: real_bin = ILA_bin - 200
VERILOG_BIN_OFFSET = 200;

% ---------- 待处理文件 ----------
% 格式: {{filepath, [target_freq_Hz, target_Vpp_mV; ...]}, ...}
% 当前任务: 单片机传输协议说明文档对应的 iladata.csv
% 实际 iladata.csv 中只有 200 kHz 单峰 (1 个目标信号),
% 如果实际是新采集的 40k+100k 数据, 请用 iladata3.csv 替换
files = { ...
    { 'C:\Users\24307\Desktop\FPGA_windows\Vivado\result\iladata.csv', ...
      [200e3, 100] } ...
};
labels = {'Single tone 200 kHz / 100 mV Vpp (real iladata.csv)'};

% ---------- 逐文件处理 ----------
fprintf('========================================================================\n');
fprintf('  Multi-Peak Spectrum Analysis (ADC-based FFT)\n');
fprintf('========================================================================\n\n');

results = cell(length(files), 1);

for k = 1:length(files)
    fp     = files{k}{1};
    targets = files{k}{2};   % Nx2 matrix: [freq_Hz, Vpp_mV]

    fprintf('===== %s =====\n', labels{k});
    fprintf('  File: %s\n', fp);
    if size(targets,1) == 1
        fprintf('  Target: %.1f kHz / %.0f mV\n\n', targets(1,1)/1e3, targets(1,2));
    else
        fprintf('  Target: ');
        for tt = 1:size(targets,1)
            fprintf('%.0f kHz/%.0f mV  ', targets(tt,1)/1e3, targets(tt,2));
        end
        fprintf('\n\n');
    end

    % ---------- 读 CSV ----------
    fid = fopen(fp, 'r');
    if fid == -1
        fprintf('  Failed to open %s\n', fp);
        continue;
    end
    fgetl(fid); fgetl(fid);     % skip header + radix

    buf_idx=[]; mag_dec=[]; bin_dec=[]; valid_dec=[]; adc_dec=[];
    while true
        ln = fgetl(fid);
        if ~ischar(ln), break; end
        ln = strtrim(ln);
        if isempty(ln), continue; end
        parts = strsplit(ln, ',');
        if length(parts) < 7, continue; end
        m = str2double(parts{4});
        b = str2double(parts{5});
        buf = str2double(parts{1});
        if isnan(m) || isnan(b) || isnan(buf), continue; end
        try
            v = hex2dec(parts{6});
            a = hex2dec(parts{7});
        catch
            continue;
        end
        if a > 2047, a = a - 4096; end
        buf_idx(end+1)  = buf;
        mag_dec(end+1)  = m;
        bin_dec(end+1)  = b;
        valid_dec(end+1)= v;
        adc_dec(end+1)  = a;
    end
    fclose(fid);

    n_valid = sum(valid_dec == 1);
    fprintf('  Total rows: %d, valid=1: %d\n', length(mag_dec), n_valid);

    % ---------- 过滤 + 按时间排序 ----------
    % 不要按 adc_dec >= 0 过滤 -- 正弦波必有负值!
    mask = (valid_dec == 1);
    bv  = bin_dec(mask);
    av  = adc_dec(mask);
    bi  = buf_idx(mask);
    [bi_sorted, ord] = sort(bi);
    bv   = bv(ord);
    av   = av(ord);
    fprintf('  Valid range: buffer [%d .. %d] (%d samples)\n', ...
        min(bi_sorted), max(bi_sorted), length(bi_sorted));

    % ---------- Wrap-around 校正 ----------
    da = diff(double(av));
    wrap_idx = find(abs(da) > ADC_RANGE/2);
    fprintf('  Wrap-arounds detected: %d\n', length(wrap_idx));
    if ~isempty(wrap_idx)
        offset = 0;
        for j = 1:length(av)
            if any(wrap_idx == (j-1))
                if da(j-1) < 0
                    offset = offset + ADC_RANGE;
                else
                    offset = offset - ADC_RANGE;
                end
            end
            av(j) = av(j) + offset;
        end
    end

    % ---------- ADC -> mV ----------
    av_mV = av * ADC_LSB_MV;
    fprintf('  ADC P2P (raw)        = %d LSB\n', max(av) - min(av));
    fprintf('  ADC P2P (bipolar)    = %.1f mV\n', max(av_mV) - min(av_mV));
    fprintf('  ADC peak (single)    = %.1f mV\n', max(abs(av_mV)));

    % ---------- FFT ----------
    x_raw = av_mV - mean(av_mV);
    x_raw = x_raw(:);   % 确保列向量
    n_real = length(x_raw);
    N = max(n_real, N_FFT);

    % Hann 窗 (与 Verilog 端 PreMul_Hann 一致)
    n_idx = (0:n_real-1)';
    hann = 0.5 * (1 - cos(2*pi*n_idx / (n_real - 1)));
    x_hann = x_raw .* hann;

    % Zero-pad 到 N_FFT (与 Verilog FFT IP 一致, 模拟其处理)
    x_padded = zeros(N, 1);
    x_padded(1:n_real) = x_hann;

    X = fft(x_padded, N);
    mag_X = abs(X) / n_real;            % |X|/n_real -> mV (sine peak amplitude)
    freq_bins = (0:N-1)' * (FS / N);

    halfN = floor(N/2) + 1;
    mag_X_half = mag_X(2:halfN);
    freq_half  = freq_bins(2:halfN);
    mag_X_full_view = mag_X_half * 2;   % |X|/n_real * 2 -> 单边谱 peak amplitude (mV, Hann-未补偿)
                                        % 注意: Hann coherent gain = 0.5, 见下方补偿

    % ---------- 多峰检测 ----------
    % 1. 找主峰 (作为归一化基准)
    [peak_max, idx_max] = max(mag_X_full_view);
    main_bin = idx_max;
    fprintf('\n  --- Main peak ---\n');
    fprintf('    bin=%d, freq=%.4f kHz, peak=%.3f mV\n', ...
        main_bin, freq_half(main_bin)/1000, peak_max);

    % 2. 自动检测所有峰 (>10% of main peak, 间距 > 8 bins)
    [all_pks, all_locs] = findpeaks(mag_X_full_view, ...
        'MinPeakHeight', max(PEAK_MIN_HEIGHT, peak_max * PEAK_MIN_RATIO), ...
        'MinPeakDistance', PEAK_MIN_DIST);
    n_peaks = length(all_pks);
    fprintf('  Peaks detected: %d (above %.1f mV threshold)\n', ...
        n_peaks, max(PEAK_MIN_HEIGHT, peak_max * PEAK_MIN_RATIO));

    % 3. 对每个峰做亚 bin 拟合
    peak_results = struct('bin', {}, 'bin5pt', {}, 'binw', {}, ...
                         'mag', {}, 'mag5pt', {}, 'magw', {}, ...
                         'freq', {}, 'freq5pt', {}, 'freqw', {});

    for p = 1:n_peaks
        pb = all_locs(p);
        pm = all_pks(p);

        % 5 点抛物线
        half = 2;
        br = (pb-half):(pb+half);
        br = br(br >= 1 & br <= length(mag_X_full_view)-1);
        m_arr = mag_X_full_view(br+1);

        if length(br) >= 3
            c2 = polyfit(br, m_arr, 2);
            bin_5pt = -c2(2) / (2*c2(1));
            mag_5pt = max(0, polyval(c2, bin_5pt));
        else
            bin_5pt = pb;
            mag_5pt = pm;
        end

        % 加权 5 点 (Gaussian weight)
        bin_w = bin_5pt;
        mag_w = mag_5pt;
        try
            if length(br) >= 3
                wts = exp(-0.5 * ((br - pb)/1.0).^2);
                cw  = polyfit(br, m_arr, 2, wts);
                bin_w = -cw(2) / (2*cw(1));
                mag_w = max(0, polyval(cw, bin_w));
            end
        catch
        end

        peak_results(p).bin    = pb;
        peak_results(p).bin5pt = bin_5pt;
        peak_results(p).binw   = bin_w;
        peak_results(p).mag    = pm;
        peak_results(p).mag5pt = mag_5pt;
        peak_results(p).magw   = mag_w;
        peak_results(p).freq   = pb * DF;
        peak_results(p).freq5pt = bin_5pt * DF;
        peak_results(p).freqw  = bin_w * DF;

        fprintf('    Peak %d: bin=%4d, freq=%7.3f kHz, mag=%.3f mV (5pt: bin=%.3f, mag=%.3f)\n', ...
            p, pb, freq_half(pb)/1000, pm, bin_5pt, mag_5pt);
    end

    % 4. 关联 targets (找最近的峰, 每个峰最多被匹配一次)
    n_targets = size(targets, 1);
    matched = zeros(n_targets, 1);
    if n_peaks >= n_targets
        % 距离矩阵: peaks × targets
        D = zeros(n_peaks, n_targets);
        for t = 1:n_targets
            target_bin = targets(t,1) / DF;
            for p = 1:n_peaks
                D(p, t) = abs(peak_results(p).binw - target_bin);
            end
        end
        % 简化: 对每个 target, 取最近的 peak (假设 peak 数 >= target 数)
        used = zeros(n_peaks, 1);
        for t = 1:n_targets
            costs = D(:, t);
            costs(used == 1) = inf;   % 已用过的 peak 不再选
            [~, best] = min(costs);
            if costs(best) < inf
                matched(t) = best;
                used(best) = 1;
            end
        end
    end

    % 5. 输出
    fprintf('\n  ==================== MULTI-PEAK RESULTS ====================\n');
    vpp_time = max(av_mV) - min(av_mV);
    for t = 1:n_targets
        if matched(t) == 0
            fprintf('    Target %d (%.1f kHz / %.0f mV): NO MATCHING PEAK\n', ...
                t, targets(t,1)/1e3, targets(t,2));
            continue;
        end
        p = matched(t);
        r = peak_results(p);

        % 用粗峰值 mag (peak_results(p).mag = mag_X_full_view at bin p)
        % 这是 findpeaks 找到的值, 比 5pt 拟合更稳定
        mag_f = r.mag;       % = |X|/N * 2 = peak amplitude (mV, Hann-未补偿)

        % 频率用粗峰 bin (findpeaks 的 bin, 更稳定)
        bin_f = r.bin;

        % 频率应用偏置: verilog 端 BinSelect 输入 = bin_cnt + 200,
        % 但 ADC 时域 FFT 的 bin 已经是真实 bin (0..8191), 无偏置
        % VERILOG_BIN_OFFSET 仅用于 reference, 这里不应用
        freq_f_adj = bin_f * DF;

        % 频率误差
        err_hz  = freq_f_adj - targets(t,1);
        err_bin = err_hz / DF;

        % 幅度校准 (基于 FFT 峰幅度, 混合信号必须用 FFT 测幅):
        %   mag_X = abs(X) / N * 2       = peak amplitude (Vpp/2)
        %   mag_hann_comp = mag_f * 2    = Vpp (Hann coherent gain = 0.5, ×2 补偿)
        %   mag_calibrated = mag_hann_comp / LINK_GAIN  (源端 Vpp)
        mag_raw_halfN = mag_f;
        mag_hann_comp = mag_f * 2;
        mag_calibrated = mag_hann_comp / LINK_GAIN;
        diff_mV = mag_calibrated - targets(t,2);

        fprintf('    Target %d (%.1f kHz / %.2f mV) -> Peak %d:\n', ...
            t, targets(t,1)/1e3, targets(t,2), p);
        fprintf('      freq       = %.4f kHz  (err %+.2f Hz = %+.4f bin)\n', ...
            freq_f_adj/1000, err_hz, err_bin);
        fprintf('      bin_w      = %.3f (weighted fit bin)\n', bin_f);
        fprintf('      bin_raw    = %d (findpeaks bin)\n', r.bin);
        fprintf('      |X|/N peak = %.3f mV (findpeaks, /N*2)\n', mag_raw_halfN);
        fprintf('      +Hann (Vpp)= %.3f mV (×2 coherent gain comp)\n', mag_hann_comp);
        fprintf('      /Gain      = %.3f mV (source estimated Vpp)\n', mag_calibrated);
        fprintf('      diff       = %+.2f mV vs target (|diff| <= 5 mV pass)\n', diff_mV);

        peak_results(p).matched_target = t;
        peak_results(p).diff_to_target = diff_mV;
        peak_results(p).freq_final = freq_f_adj;
        peak_results(p).mag_final = mag_calibrated;
    end

    % ---------- 画图 ----------
    fig = figure('Position',[100 100 1400 500], 'Visible','off');

    % 左: 全频段频谱
    subplot(1,2,1);
    plot(freq_half/1000, mag_X_full_view, 'b-', 'LineWidth', 0.6); hold on;
    for p = 1:n_peaks
        r = peak_results(p);
        plot(r.freqw/1000, r.magw*2, 'rv', 'MarkerSize', 10, 'LineWidth', 2);
        text(r.freqw/1000, r.magw*2*1.05, sprintf('%.1f kHz', r.freqw/1000), ...
            'HorizontalAlignment', 'center', 'FontSize', 9);
    end
    for t = 1:n_targets
        xline(targets(t,1)/1000, 'k--', 'LineWidth', 1.0);
    end
    xlabel('Frequency (kHz)');
    ylabel('Amplitude (mV, peak w/ Hann comp)');
    title(sprintf('%s | %d peaks detected', labels{k}, n_peaks));
    legend({sprintf('ADC FFT (full spectrum)'), ...
            sprintf('%d detected peaks', n_peaks), ...
            sprintf('%d target lines', n_targets)}, 'Location', 'northeast');
    grid on; xlim([0 FS/2/1000]);

    % 右: 局部放大
    subplot(1,2,2);
    if size(targets,1) == 1
        center_f = targets(1,1);
        span = max(20, 5 * DF * 100 / 1000);   % 自动选 ±20 kHz 或 ±20 bin
    else
        center_f = mean(targets(:,1));
        span = 30;
    end
    sel = (freq_half/1000 >= center_f/1e3-span) & (freq_half/1000 <= center_f/1e3+span);
    plot(freq_half(sel)/1000, mag_X_full_view(sel), 'b-o', 'LineWidth', 1.0, 'MarkerSize', 4);
    hold on;
    for t = 1:size(targets,1)
        if matched(t) > 0
            p = matched(t);
            r = peak_results(p);
            plot(r.freqw/1000, r.magw*2, 'rv', 'MarkerSize', 12, 'LineWidth', 2);
        end
        xline(targets(t,1)/1000, 'k--', 'LineWidth', 1.0);
    end
    xlabel('Frequency (kHz)');
    ylabel('Amplitude (mV)');
    title(sprintf('Zoom \\pm%.0f kHz', span));
    legend({'FFT bins', 'detected peaks', 'targets'}, 'Location', 'northeast');
    grid on;

    [~, base, ~] = fileparts(fp);
    out_png = fullfile(FIG_DIR, ['adc_fft_multi_' base '.png']);
    try
        exportgraphics(fig, out_png, 'Resolution', 90);
    catch
        saveas(fig, out_png);
    end
    close(fig);

    results{k} = struct( ...
        'label', labels{k}, ...
        'file',  fp, ...
        'targets', targets, ...
        'matched', matched, ...
        'peaks', peak_results, ...
        'adc_vpp_mV', vpp_time);
end

% ---------- 总表 ----------
fprintf('\n========================================================================\n');
fprintf('            Multi-Peak Summary (All Files)\n');
fprintf('========================================================================\n');
fprintf('  Target (Hz)   | Meas (Hz)    | Err (Hz)   | Err (bin) | Tgt Vpp | Meas Vpp | Diff\n');
fprintf('  --------------+--------------+------------+-----------+---------+----------+------\n');
for k = 1:length(results)
    if isempty(results{k}), continue; end
    r = results{k};
    targets = r.targets;
    matched = r.matched;
    peaks = r.peaks;
    n_t = size(targets,1);
    for t = 1:n_t
        if matched(t) == 0
            fprintf('  %-13s | %-13s | %-11s | %-10s | %-7s | %-8s | NO MATCH\n', ...
                sprintf('%.0f', targets(t,1)), '-', '-', '-', ...
                sprintf('%.2f', targets(t,2)), '-');
            continue;
        end
        p = matched(t);
        pk = peaks(p);
        fprintf('  %-13s | %-13s | %+10.2f | %+9.4f | %-7.2f | %8.3f | %+5.2f\n', ...
            sprintf('%.0f', targets(t,1)), ...
            sprintf('%.2f', pk.freq_final), ...
            pk.freq_final - targets(t,1), ...
            (pk.freq_final - targets(t,1)) / DF, ...
            targets(t,2), pk.mag_final, pk.diff_to_target);
    end
end
fprintf('========================================================================\n');
fprintf('Done.\n');