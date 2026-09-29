% ============================================================================
% B2.1 MATLAB script — ADC 双通道同步采样频谱分析 (40 MHz MMCM, 1/2 MHz)
% ============================================================================
% 文件: read_dual_adc.m
% 功能: 读取 Vivado ILA 导出的 CSV (或 Python 仿真器生成的 sim_dump.csv),
%       转换 ADC 码 -> 电压, 高阶截断前 8000 点做 FFT, 输出时域图 + 频谱图.
%
% 用法:
%   方法 1 (Vivado 真实采集数据, 默认):
%     1. 在 Vivado Hardware Manager 里 "Export ILA Data" 选 CSV,
%        保存到 source/ila_dump.csv
%        (列名是 u_core/core/io_adc_data_a[11:0] 等, 自动识别)
%     2. cd('C:/Users/24307/Desktop/FPGA_windows/matlab/B2_1/code')
%        read_dual_adc
%
%   方法 2 (Python 仿真数据, 用于流程验证):
%     read_dual_adc('C:/Users/24307/Desktop/FPGA_windows/Vivado/result/B2_1/sim/sim_dump.csv')
%
% 物理约定:
%   - AD9226 单端差分输入范围 ±1V (内部 AD8138 差分驱动)
%   - 12-bit ADC: code 0 = -1V, code 2048 = 0V, code 4095 ≈ +1V
%   - V = (code - 2048) / 2048  (单位 V)
%   - 采样率 fs = 40 MHz (PL 50MHz 主时钟经 MMCM 倍频分频得到)
%   - N_FFT = 8000 (高阶截断: 从 8192 个 ILA 抓取点截取前 8000 点)
%   - Δf = fs / N_FFT = 5 kHz (整数 bin 分辨率)
%   - Channel A 输入 1.000 MHz -> bin 200; Channel B 输入 2.000 MHz -> bin 400
% ============================================================================

function read_dual_adc(csv_path)
    if nargin < 1
        % 默认从 source/ 读 Vivado ILA 导出
        csv_path = 'C:/Users/24307/Desktop/FPGA_windows/matlab/B2_1/source/ila_dump.csv';
    end

    % 工具路径
    fig_dir = 'C:/Users/24307/Desktop/FPGA_windows/matlab/B2_1/figure';

    fprintf('=========================================================================\n');
    fprintf('| B2.1 MATLAB spectrum analyzer (40 MHz MMCM, 1/2 MHz, 8000-point FFT)\n');
    fprintf('| CSV: %s\n', csv_path);
    fprintf('=========================================================================\n');

    if ~exist(csv_path, 'file')
        error('CSV 文件不存在: %s', csv_path);
    end

    % 智能读 CSV: Vivado ILA 导出格式 vs Python sim 格式
    fid = fopen(csv_path, 'r');
    header = fgetl(fid);
    fclose(fid);
    fprintf('| CSV header: %s\n', header);

    if contains(header, 'a_sync')
        % ===== Python sim 格式: n,a_raw,b_raw,a_sync,b_sync,ora,orb =====
        data = readmatrix(csv_path);
        n      = data(:, 1);
        a_sync = data(:, 4);
        b_sync = data(:, 5);
        a_raw  = data(:, 2);
        b_raw  = data(:, 3);
    elseif contains(header, 'io_adc_data_a')
        % ===== Vivado ILA 导出格式 =====
        % 实际列:
        %   1: Sample in Buffer
        %   2: Sample in Window
        %   3: TRIGGER
        %   4: u_core/core/io_adc_data_b[11:0]
        %   5: u_core/core/io_adc_data_a[11:0]
        %   6: u_core/core/io_ora
        %   7: u_core/core/io_orb
        % ILA 导出有 2 行 header: 第 1 行列名, 第 2 行 Radix (UNSIGNED 等)
        raw = readmatrix(csv_path, 'NumHeaderLines', 2);
        % 整理成 n + 4 个信号
        a_sync = raw(:, 5);   % io_adc_data_a[11:0]
        b_sync = raw(:, 4);   % io_adc_data_b[11:0]
        ora    = raw(:, 6);
        orb    = raw(:, 7);
        n      = raw(:, 1);
    else
        % ===== 通用尝试: 第 1 行列名, 直接读 =====
        T = readtable(csv_path);
        if ismember('adc_data_a', T.Properties.VariableNames) && ismember('adc_data_b', T.Properties.VariableNames)
            a_sync = T.adc_data_a;
            b_sync = T.adc_data_b;
        elseif ismember('a_sync', T.Properties.VariableNames)
            a_sync = T.a_sync;
            b_sync = T.b_sync;
        else
            error('CSV 列名不匹配, 期望 io_adc_data_a / adc_data_a / a_sync 之一');
        end
        n = (0:length(a_sync)-1)';
    end

    N = length(n);
    fprintf('| 加载 %d 个采样点\n', N);

    % ADC 码 -> 电压 (前 N_FFT 点 = 高阶截断)
    N_FFT = 8000;
    a_full = (double(a_sync) - 2048) / 2048;
    b_full = (double(b_sync) - 2048) / 2048;
    a_v = a_full(1:N_FFT);
    b_v = b_full(1:N_FFT);

    fprintf('| Ch A (前 %d 点, code 范围): min=%d, max=%d, DC=%.1f\n', ...
            N_FFT, min(a_sync(1:N_FFT)), max(a_sync(1:N_FFT)), ...
            mean(double(a_sync(1:N_FFT))));
    fprintf('| Ch B (前 %d 点, code 范围): min=%d, max=%d, DC=%.1f\n', ...
            N_FFT, min(b_sync(1:N_FFT)), max(b_sync(1:N_FFT)), ...
            mean(double(b_sync(1:N_FFT))));
    fprintf('| Ch A (去 DC 后) voltage: pk-pk = %.3f V\n', max(a_v)-min(a_v));
    fprintf('| Ch B (去 DC 后) voltage: pk-pk = %.3f V\n', max(b_v)-min(b_v));

    % === 时域图 ===
    figure('Name', 'B2.1 时域 (40 MSPS, 1/2 MHz, ILA 实采)');
    subplot(2, 1, 1);
    n_show = min(200, N_FFT);    % 前 200 点 (5 µs @ 40 MSPS)
    t_us = (0:n_show-1)' / 40e6 * 1e6;
    plot(t_us, a_v(1:n_show), 'b-', 'LineWidth', 1.0);
    xlabel('Time (µs)');
    ylabel('Voltage (V, 已去 DC)');
    title('Ch A — Time Domain (ILA captured)');
    grid on;

    subplot(2, 1, 2);
    plot(t_us, b_v(1:n_show), 'r-', 'LineWidth', 1.0);
    xlabel('Time (µs)');
    ylabel('Voltage (V, 已去 DC)');
    title('Ch B — Time Domain (ILA captured)');
    grid on;

    saveas(gcf, fullfile(fig_dir, 'b2_1_timedomain.fig'));
    saveas(gcf, fullfile(fig_dir, 'b2_1_timedomain.png'));
    fprintf('| Saved: %s/b2_1_timedomain.png\n', fig_dir);

    % === FFT 频谱 (40 MSPS, N_FFT=8000, Δf=5 kHz) ===
    fs = 40e6;
    [aFreq, aDb] = do_fft(a_v, fs);
    [bFreq, bDb] = do_fft(b_v, fs);

    figure('Name', 'B2.1 频谱 (40 MSPS, 1/2 MHz)');
    subplot(2, 1, 1);
    plot(aFreq / 1e6, aDb, 'b-', 'LineWidth', 0.7);
    xlabel('Frequency (MHz)');
    ylabel('Magnitude (dBFS, 0 dB = 1V peak)');
    title('Ch A Spectrum — expected peak at 1.0 MHz (bin 200)');
    grid on;
    xlim([0, 4]);
    ylim([-80, 0]);
    xline(1.0, '--r', '1 MHz (bin 200)');
    hold on;
    [a_peak_f, a_peak_db] = find_peak(aFreq, aDb, 1e6, 1e4);
    plot(a_peak_f/1e6, a_peak_db, 'g^', 'MarkerSize', 10, 'MarkerFaceColor', 'g');
    text(a_peak_f/1e6, a_peak_db + 5, ...
         sprintf('%.4f MHz, %.1f dBFS', a_peak_f/1e6, a_peak_db));
    hold off;

    subplot(2, 1, 2);
    plot(bFreq / 1e6, bDb, 'r-', 'LineWidth', 0.7);
    xlabel('Frequency (MHz)');
    ylabel('Magnitude (dBFS, 0 dB = 1V peak)');
    title('Ch B Spectrum — expected peak at 2.0 MHz (bin 400)');
    grid on;
    xlim([0, 4]);
    ylim([-80, 0]);
    xline(2.0, '--r', '2 MHz (bin 400)');
    hold on;
    [b_peak_f, b_peak_db] = find_peak(bFreq, bDb, 2e6, 1e4);
    plot(b_peak_f/1e6, b_peak_db, 'g^', 'MarkerSize', 10, 'MarkerFaceColor', 'g');
    text(b_peak_f/1e6, b_peak_db + 5, ...
         sprintf('%.4f MHz, %.1f dBFS', b_peak_f/1e6, b_peak_db));
    hold off;

    saveas(gcf, fullfile(fig_dir, 'b2_1_spectrum.fig'));
    saveas(gcf, fullfile(fig_dir, 'b2_1_spectrum.png'));
    fprintf('| Saved: %s/b2_1_spectrum.png\n', fig_dir);

    % === 主峰检测 + 串扰 ===
    bin_res = fs / N_FFT;     % 5 kHz
    [a_peak_f, a_peak_db] = find_peak(aFreq, aDb, 1e6, bin_res / 2);
    [b_peak_f, b_peak_db] = find_peak(bFreq, bDb, 2e6, bin_res / 2);
    fprintf('| Ch A 主峰: %.4f Hz (bin %d), %.1f dBFS  (期望 1.0 MHz / bin 200)\n', ...
            a_peak_f, round(a_peak_f / bin_res), a_peak_db);
    fprintf('| Ch B 主峰: %.4f Hz (bin %d), %.1f dBFS  (期望 2.0 MHz / bin 400)\n', ...
            b_peak_f, round(b_peak_f / bin_res), b_peak_db);

    err_a = abs(a_peak_f - 1e6);
    err_b = abs(b_peak_f - 2e6);
    if err_a < 1e3 && err_b < 1e3
        fprintf('| [PASS] 主峰落在整数 bin (零频谱泄漏)\n');
    else
        fprintf('| [WARN] 主峰偏离整数 bin > 1 kHz\n');
    end

    % 串扰检查
    [~, a_cross_db] = find_peak(aFreq, aDb, 2e6, bin_res / 2);
    [~, b_cross_db] = find_peak(bFreq, bDb, 1e6, bin_res / 2);
    fprintf('| Ch A @ 2 MHz (串扰): %.1f dBFS (主峰 %.1f, 隔离度 %.1f dB)\n', ...
            a_cross_db, a_peak_db, a_peak_db - a_cross_db);
    fprintf('| Ch B @ 1 MHz (串扰): %.1f dBFS (主峰 %.1f, 隔离度 %.1f dB)\n', ...
            b_cross_db, b_peak_db, b_peak_db - b_cross_db);

    fprintf('=========================================================================\n');
    fprintf('[OK] 分析完成, 图保存在 %s\n', fig_dir);
end


function [freqs, mag_db] = do_fft(signal, fs)
    N = length(signal);
    sig = signal - mean(signal);              % 去 DC
    win = hann(N);                            % Hanning 窗
    sig_w = sig .* win;
    X = fft(sig_w);
    X_mag = abs(X(1:N/2)) / (sum(win)/2);
    X_mag(1) = X_mag(1) / 2;                  % DC 补偿
    mag_db = 20*log10(max(X_mag, 1e-6));
    freqs = (0:N/2-1) * fs / N;
end


function [peak_f, peak_db] = find_peak(freqs, mag_db, target_hz, search_hz)
    mask = abs(freqs - target_hz) <= search_hz;
    if ~any(mask)
        peak_f = NaN; peak_db = NaN;
        return;
    end
    idxs = find(mask);
    [peak_db, k] = max(mag_db(idxs));
    peak_f = freqs(idxs(k));
end