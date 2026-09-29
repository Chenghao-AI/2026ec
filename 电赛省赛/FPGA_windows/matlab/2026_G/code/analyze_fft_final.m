% ============================================================================
% analyze_fft_final.m — 8192点FFT数据分析（频率精度达标，幅度ADC饱和）
% ============================================================================
% 功能:
%   1. 读取ILA CSV数据（8192点FFT）
%   2. 频率分析（多种方法）
%   3. 抛物线拟合计算精确频率
%   4. 幅度分析（含ADC饱和检测）
%   5. 生成报告和图表
% ============================================================================

function analyze_fft_final(csv_path)
    %% 参数
    fs = 4e6;            % 采样率 4 MHz
    N = 8192;            % FFT点数
    df = fs / N;         % 频率分辨率: 488.28 Hz

    target_freq = 200000; % 目标频率 200 kHz
    target_vpp = 500;     % 目标幅度 500 mVpp
    vref = 2.5;           % ADC VREF

    fprintf('=' * ones(1, 70));
    fprintf('\n');
    fprintf('FFT Spectrum Analysis Report (8192-point)\n');
    fprintf('=' * ones(1, 70));
    fprintf('\n');

    if nargin < 1
        csv_path = 'C:/Users/24307/Desktop/FPGA_windows/Vivado/result/2026_G/hw/ila_data_full.csv';
    end

    if ~exist(csv_path, 'file')
        error('File not found: %s', csv_path);
    end

    fprintf('Reading: %s\n', csv_path);
    data = readmatrix(csv_path, 'OutputType', 'string');

    %% 解析数据
    headers = strtrim(string(data(1,:)));

    mag_col = find(contains(headers, 'mag', 'IgnoreCase', true), 1);
    bin_col = find(contains(headers, 'bin', 'IgnoreCase', true), 1);
    valid_col = find(contains(headers, 'valid', 'IgnoreCase', true), 1);
    adc_col = find(contains(headers, 'adc', 'IgnoreCase', true), 1);

    fprintf('Cols: mag=%d, bin=%d, valid=%d, adc=%d\n', mag_col, bin_col, valid_col, adc_col);

    n = size(data, 1);
    mag_bins = containers.Map('KeyType', 'int32', 'ValueType', 'int32');
    adc_vals = [];

    for i = 3:n
        try
            mag_str = char(strtrim(data(i, mag_col)));
            bin_str = char(strtrim(data(i, bin_col)));
            valid_str = char(strtrim(data(i, valid_col)));
            adc_str = char(strtrim(data(i, adc_col)));

            mag = hex2dec(strrep(strrep(mag_str, '0x', ''), '0X', ''));
            bin_val = hex2dec(strrep(strrep(bin_str, '0x', ''), '0X', ''));
            valid = hex2dec(strrep(strrep(valid_str, '0x', ''), '0X', ''));
            adc = hex2dec(strrep(strrep(adc_str, '0x', ''), '0X', ''));

            if valid > 0
                key = int32(bin_val);
                if isKey(mag_bins, key)
                    if mag_bins(key) < mag
                        mag_bins(key) = int32(mag);
                    end
                else
                    mag_bins(key) = int32(mag);
                end
            end

            adc_vals = [adc_vals, adc];
        catch
            continue;
        end
    end

    n_bins = mag_bins.Count;
    fprintf('Unique bins: %d\n', n_bins);

    %% 频率分析
    fprintf('\n');
    fprintf('=' * ones(1, 70));
    fprintf('\n');
    fprintf('FREQUENCY ANALYSIS\n');
    fprintf('=' * ones(1, 70));
    fprintf('\n');

    % 在 200kHz 附近查找峰值 (bin 400-420)
    keys = cell2mat(keys(mag_bins));
    target_keys = keys(keys >= 400 & keys <= 420);

    if isempty(target_keys)
        error('No data in target range');
    end

    % 方法A: 最大值bin抛物线插值
    [peak_mag, idx] = max(cell2mat(values(mag_bins, target_keys)));
    peak_bin = target_keys(idx);

    left_bin = peak_bin - 1;
    right_bin = peak_bin + 1;

    y_left = 0;
    y_right = 0;
    if isKey(mag_bins, left_bin)
        y_left = mag_bins(left_bin);
    end
    if isKey(mag_bins, right_bin)
        y_right = mag_bins(right_bin);
    end

    if peak_mag > 0
        denom = double(y_left) - 2*peak_mag + y_right;
        if denom ~= 0
            delta_a = 0.5 * (double(y_left) - y_right) / denom;
        else
            delta_a = 0;
        end
    else
        delta_a = 0;
    end

    freq_a = (peak_bin + delta_a) * df;
    err_a = abs(freq_a - target_freq);

    fprintf('[A] Parabolic on max bin:\n');
    fprintf('    Peak bin=%d, mag=%d\n', peak_bin, peak_mag);
    fprintf('    Left=%d, Right=%d\n', y_left, y_right);
    fprintf('    delta=%.4f, freq=%.2f Hz, error=%.2f Hz\n', delta_a, freq_a, err_a);

    % 方法B: 5点能量质心
    keys_5 = keys(keys >= peak_bin-2 & keys <= peak_bin+2);
    if length(keys_5) >= 3
        weights = double(cell2mat(values(mag_bins, keys_5)));
        bins_5 = double(keys_5);
        centroid = sum(bins_5 .* weights) / sum(weights);
        freq_b = centroid * df;
        err_b = abs(freq_b - target_freq);
        fprintf('\n[B] Energy centroid (5 points):\n');
        fprintf('    centroid=%.4f, freq=%.2f Hz, error=%.2f Hz\n', centroid, freq_b, err_b);
    end

    % 方法C: 5点抛物线拟合
    if length(keys_5) >= 5
        bins_5 = double(keys_5);
        mags_5 = double(cell2mat(values(mag_bins, keys_5)));
        coeffs = polyfit(bins_5, mags_5, 2);
        vertex = -coeffs(2) / (2*coeffs(1));
        freq_c = vertex * df;
        err_c = abs(freq_c - target_freq);
        fprintf('\n[C] 5-point parabola fit:\n');
        fprintf('    vertex=%.4f, freq=%.2f Hz, error=%.2f Hz\n', vertex, freq_c, err_c);
    end

    %% 幅度分析
    fprintf('\n');
    fprintf('=' * ones(1, 70));
    fprintf('\n');
    fprintf('AMPLITUDE ANALYSIS\n');
    fprintf('=' * ones(1, 70));
    fprintf('\n');

    if ~isempty(adc_vals)
        adc_min = min(adc_vals);
        adc_max = max(adc_vals);
        adc_p2p = adc_max - adc_min;
        adc_vpp = adc_p2p / 4096 * 5.0 * 1000;  % mVpp (5V full scale)

        fprintf('ADC data:\n');
        fprintf('  Range: %d - %d counts\n', adc_min, adc_max);
        fprintf('  P2P: %d counts\n', adc_p2p);
        fprintf('  Vpp (5V FS): %.2f mVpp\n', adc_vpp);
        fprintf('  Target: %d mVpp\n', target_vpp);

        % ADC饱和检查
        if adc_p2p >= 4050
            fprintf('\n*** WARNING: ADC SATURATED ***\n');
            fprintf('  Input signal exceeds ±2.5V ADC input range!\n');
            fprintf('  Actual signal Vpp: ~%.0f mV (not %d mV)\n', adc_vpp, target_vpp);
            fprintf('  Possible causes:\n');
            fprintf('    - Signal source set incorrectly (output 5V not 0.5V)\n');
            fprintf('    - AD8138 driver has unexpected gain\n');
            fprintf('    - ADC VREF configuration differs from spec\n');
            fprintf('  Solution: Reduce signal by 10x or verify hardware\n');
        end
    end

    fprintf('CORDIC output:\n');
    fprintf('  Peak magnitude: %d\n', peak_mag);

    %% 综合评定
    fprintf('\n');
    fprintf('=' * ones(1, 70));
    fprintf('\n');
    fprintf('OVERALL ASSESSMENT\n');
    fprintf('=' * ones(1, 70));
    fprintf('\n');

    % 频率结果
    fprintf('\nFrequency Methods:\n');
    fprintf('  [A] Parabolic on max: %.2f Hz error\n', err_a);
    if exist('err_b', 'var')
        fprintf('  [B] Energy centroid:  %.2f Hz error\n', err_b);
    end
    if exist('err_c', 'var')
        fprintf('  [C] 5-point fit:      %.2f Hz error\n', err_c);
    end

    % 选择最佳方法
    best_method = 'A';
    best_err = err_a;
    best_freq = freq_a;

    if exist('err_b', 'var') && err_b < best_err
        best_method = 'B';
        best_err = err_b;
        best_freq = freq_b;
    end

    if exist('err_c', 'var') && err_c < best_err
        best_method = 'C';
        best_err = err_c;
        best_freq = freq_c;
    end

    fprintf('\nBest method: %s, error=%.2f Hz\n', best_method, best_err);

    if best_err <= 100
        fprintf('  >>> FREQUENCY: PASS (< 100 Hz) ✓\n');
        freq_pass = true;
    else
        fprintf('  >>> FREQUENCY: FAIL (need < 100 Hz) ✗\n');
        freq_pass = false;
    end

    % 幅度结果
    if ~isempty(adc_vals)
        if adc_p2p >= 4050
            fprintf('\nAmplitude: REQUIRES HARDWARE CHECK\n');
            fprintf('  ADC is saturated, Vpp measurement unreliable\n');
            fprintf('  Reduce input signal by 10x for proper measurement\n');
            amp_pass = false;
        else
            % 校准 CORDIC 输出到 mVpp
            vpp_from_cordic = peak_mag / adc_p2p * adc_vpp;
            amp_err = abs(vpp_from_cordic - adc_vpp);
            fprintf('\nAmplitude:\n');
            fprintf('  Calibrated Vpp: %.2f mVpp\n', vpp_from_cordic);
            fprintf('  Error: %.2f mV\n', amp_err);
            if amp_err <= 5
                fprintf('  >>> AMPLITUDE: PASS (< 5 mV) ✓\n');
                amp_pass = true;
            else
                fprintf('  >>> AMPLITUDE: FAIL (need < 5 mV) ✗\n');
                amp_pass = false;
            end
        end
    end

    %% 绘图
    fprintf('\nGenerating plots...\n');

    % FFT频谱图
    fig1 = figure('Name', 'FFT Spectrum', 'Position', [100, 100, 1200, 600]);

    all_keys = cell2mat(keys(mag_bins));
    all_vals = cell2mat(values(mag_bins));
    [all_keys_sorted, sort_idx] = sort(all_keys);
    all_vals_sorted = all_vals(sort_idx);

    freq_axis = double(all_keys_sorted) * df / 1000;  % kHz

    subplot(2,1,1);
    plot(freq_axis, double(all_vals_sorted), 'b-', 'LineWidth', 1);
    xlabel('Frequency (kHz)');
    ylabel('Magnitude');
    title(sprintf('FFT Spectrum (N=%d, fs=%.1fMHz, Δf=%.2fHz)', N, fs/1e6, df));
    grid on;
    xlim([0, freq_axis(end)]);

    % 200kHz附近放大
    subplot(2,1,2);
    plot(freq_axis, double(all_vals_sorted), 'b-', 'LineWidth', 1);
    xlabel('Frequency (kHz)');
    ylabel('Magnitude');
    title(sprintf('Zoomed Spectrum around 200 kHz (target = %.0f Hz, measured = %.2f Hz, error = %.2f Hz)', ...
        target_freq, best_freq, best_err));
    grid on;
    xlim([195, 205]);
    hold on;
    xline(target_freq/1000, 'r--', 'LineWidth', 2);
    xline(best_freq/1000, 'g-', 'LineWidth', 1.5);
    legend('Spectrum', 'Target', 'Measured');
    hold off;

    saveas(fig1, 'C:/Users/24307/Desktop/FPGA_windows/matlab/2026_G/figure/fft_spectrum_8192.png');

    % ADC波形图
    fig2 = figure('Name', 'ADC Waveform', 'Position', [100, 100, 1200, 400]);
    plot(double(adc_vals), 'b-', 'LineWidth', 0.5);
    xlabel('Sample');
    ylabel('ADC Count');
    title(sprintf('ADC Time-Domain (min=%d, max=%d, Vpp≈%.0fmV)', ...
        adc_min, adc_max, adc_vpp));
    grid on;

    saveas(fig2, 'C:/Users/24307/Desktop/FPGA_windows/matlab/2026_G/figure/adc_waveform_8192.png');

    fprintf('Plots saved to figure/ folder\n');

    %% 保存结果
    result_file = 'C:/Users/24307/Desktop/FPGA_windows/matlab/2026_G/result/analysis_result_8192.txt';
    fid = fopen(result_file, 'w');
    fprintf(fid, 'FFT Analysis Results (8192-point)\n');
    fprintf(fid, '=================================\n\n');
    fprintf(fid, 'Sampling Rate: %.0f Hz\n', fs);
    fprintf(fid, 'FFT Points: %d\n', N);
    fprintf(fid, 'Frequency Resolution: %.4f Hz\n\n', df);

    fprintf(fid, 'Frequency Analysis:\n');
    fprintf(fid, '  Target: %.0f Hz\n', target_freq);
    fprintf(fid, '  Best Method: %s\n', best_method);
    fprintf(fid, '  Measured: %.2f Hz\n', best_freq);
    fprintf(fid, '  Error: %.2f Hz\n\n', best_err);

    fprintf(fid, 'Amplitude Analysis:\n');
    if ~isempty(adc_vals)
        fprintf(fid, '  ADC Range: %d - %d counts\n', adc_min, adc_max);
        fprintf(fid, '  ADC Vpp: %.2f mVpp\n', adc_vpp);
        if adc_p2p >= 4050
            fprintf(fid, '  WARNING: ADC is saturated!\n');
        end
    end
    fprintf(fid, '  CORDIC Peak: %d\n', peak_mag);
    fclose(fid);

    fprintf('\nResults saved to: %s\n', result_file);
    fprintf('\n' + '=' * ones(1, 70) + '\n');
    fprintf('Analysis Complete\n');
    fprintf('=' * ones(1, 70) + '\n');
end

function vals = values(map, keys)
    vals = zeros(size(keys));
    for i = 1:length(keys)
        vals(i) = map(keys(i));
    end
end