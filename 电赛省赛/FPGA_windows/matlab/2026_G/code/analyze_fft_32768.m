% ============================================================================
% analyze_fft_32768.m — 32768点FFT数据分析
% ============================================================================
% 功能:
%   1. 从ILA CSV文件读取FFT数据
%   2. 进行频谱分析
%   3. 抛物线插值精确计算频率
%   4. 幅度校准
%   5. 生成报告和图表
%
% 参数:
%   采样率: 4 MHz
%   FFT点数: 32768
%   频率分辨率: 122.07 Hz
%   扫频范围: 0~1.25 MHz
% ============================================================================

function analyze_fft_32768(csv_path)
    %% 参数
    fs = 4e6;           % 采样率 4 MHz
    N = 32768;          % FFT点数
    df = fs / N;         % 频率分辨率: 122.07 Hz
    
    target_freq = 200000; % 目标频率 200 kHz
    target_vpp = 500;    % 目标幅度 500 mVpp
    
    fprintf('=' * ones(1, 70));
    fprintf('\n');
    fprintf('32768点FFT 频谱分析\n');
    fprintf('=' * ones(1, 70));
    fprintf('\n\n');
    
    %% 读取CSV数据
    fprintf('[1] 读取数据...\n');
    if nargin < 1
        csv_path = 'C:\Users\24307\Desktop\FPGA_windows\Vivado\result\2026_G\hw\ila_data_full.csv';
    end
    
    if ~exist(csv_path, 'file')
        error('文件不存在: %s', csv_path);
    end
    
    % 读取CSV
    data = readmatrix(csv_path, 'OutputType', 'string');
    
    % 解析表头
    headers = data(1, :);
    
    % 找到探针列索引
    mag_col = find(contains(headers, 'mag'));
    bin_col = find(contains(headers, 'bin'));
    valid_col = find(contains(headers, 'valid'));
    adc_col = find(contains(headers, 'adc'));
    
    if isempty(mag_col) || isempty(bin_col)
        error('未找到 mag 或 bin 列');
    end
    
    fprintf('  找到列: mag=%d, bin=%d, valid=%d, adc=%d\n', ...
        mag_col, bin_col, valid_col, adc_col);
    
    % 解析数据行
    fprintf('[2] 解析数据...\n');
    mag_bins = containers.Map('KeyType', 'double', 'ValueType', 'double');
    adc_vals = [];
    
    for i = 3:size(data, 1)
        try
            bin_val = hex2dec(data{i, bin_col}{1});
            mag_val = hex2dec(data{i, mag_col}{1});
            valid = hex2dec(data{i, valid_col}{1});
            
            if valid > 0 && bin_val < N
                if ~isKey(mag_bins, bin_val)
                    mag_bins(bin_val) = mag_val;
                else
                    mag_bins(bin_val) = max(mag_bins(bin_val), mag_val);
                end
            end
            
            if ~isempty(adc_col)
                adc_val = hex2dec(data{i, adc_col}{1});
                adc_vals = [adc_vals, adc_val];
            end
        catch
            % 跳过无效行
        end
    end
    
    fprintf('  有效bin数: %d\n', mag_bins.Count);
    
    if isempty(adc_vals)
        fprintf('  ADC数据: 无\n');
    else
        fprintf('  ADC范围: %d ~ %d (峰峰值: %d)\n', ...
            min(adc_vals), max(adc_vals), max(adc_vals) - min(adc_vals));
    end
    
    %% 频谱分析
    fprintf('\n[3] 频谱分析...\n');
    fprintf('  频率分辨率: %.4f Hz\n', df);
    fprintf('  目标bin: %.2f\n', target_freq / df);
    
    % 找峰值
    bins = cell2mat(mag_bins.keys);
    mags = cell2mat(mag_bins.values);
    [~, idx] = max(mags);
    peak_bin = bins(idx);
    peak_mag = mags(idx);
    peak_freq = peak_bin * df;
    
    fprintf('  峰值bin: %d\n', peak_bin);
    fprintf('  峰值频率: %.2f Hz\n', peak_freq);
    fprintf('  峰值幅度: %d\n', peak_mag);
    
    %% 抛物线插值
    fprintf('\n[4] 抛物线插值...\n');
    
    y_minus = mag_bins(peak_bin - 1);
    y_peak = peak_mag;
    y_plus = mag_bins(peak_bin + 1);
    
    fprintf('  相邻bin幅度: %d, %d, %d\n', y_minus, y_peak, y_plus);
    
    delta = 0.5 * (y_minus - y_plus) / (y_minus - 2*y_peak + y_plus);
    exact_bin = peak_bin + delta;
    exact_freq = exact_bin * df;
    freq_error = abs(exact_freq - target_freq);
    
    fprintf('  插值偏移: %.4f\n', delta);
    fprintf('  精确bin: %.4f\n', exact_bin);
    fprintf('  精确频率: %.2f Hz\n', exact_freq);
    fprintf('  频率误差: %.2f Hz\n', freq_error);
    
    if freq_error <= 100
        fprintf('  >>> 频率精度: PASS (< 100 Hz)\n');
    else
        fprintf('  >>> 频率精度: FAIL (> 100 Hz)\n');
    end
    
    %% 幅度校准
    fprintf('\n[5] 幅度校准...\n');
    
    % FFT缩放因子
    fft_gain = N / 2;  % 4096
    
    % ADC换算 (假设VREF = 2.5V)
    vref = 2.5;
    
    % 从CORDIC输出反推
    recovered_adc = peak_mag * fft_gain;
    recovered_peak_adc = recovered_adc / fft_gain;
    recovered_peak_v = recovered_peak_adc / 2048 * vref;
    recovered_vpp = recovered_peak_v * 2 * 1000;  % mVpp
    
    fprintf('  CORDIC峰值: %d\n', peak_mag);
    fprintf('  FFT缩放: %d\n', fft_gain);
    fprintf('  恢复ADC值: %.2f\n', recovered_adc);
    fprintf('  恢复电压峰值: %.4f mV\n', recovered_peak_v * 1000);
    fprintf('  恢复峰峰值: %.2f mVpp\n', recovered_vpp);
    fprintf('  目标峰峰值: %d mVpp\n', target_vpp);
    fprintf('  幅度误差: %.2f mVpp\n', abs(recovered_vpp - target_vpp));
    
    if abs(recovered_vpp - target_vpp) <= 5
        fprintf('  >>> 幅度精度: PASS (< 5 mV)\n');
    else
        fprintf('  >>> 幅度精度: FAIL (> 5 mV)\n');
    end
    
    %% 目标区域分析
    fprintf('\n[6] 目标频率区域分析 (bin %d ~ %d)...\n', ...
        floor(target_freq/df) - 10, floor(target_freq/df) + 10);
    
    fprintf('  %-8s %-12s %-12s\n', 'Bin', '频率(Hz)', '幅度');
    fprintf('  ' * ones(1, 35));
    fprintf('\n');
    
    for b = floor(target_freq/df) - 10:floor(target_freq/df) + 10
        if mag_bins.isKey(b)
            freq = b * df;
            mag = mag_bins(b);
            bar = '*' * ones(1, max(1, floor(mag / 1000)));
            fprintf('  %-8d %-12.2f %-12d %s\n', b, freq, mag, bar);
        else
            freq = b * df;
            fprintf('  %-8d %-12.2f %-12s\n', b, freq, '(无数据)');
        end
    end
    
    %% 保存结果
    fprintf('\n[7] 保存结果...\n');
    
    result_dir = 'C:\Users\24307\Desktop\FPGA_windows\matlab\2026_G\result';
    if ~exist(result_dir, 'dir')
        mkdir(result_dir);
    end
    
    % 保存数值结果
    result_file = fullfile(result_dir, 'fft_analysis_result.txt');
    fid = fopen(result_file, 'w');
    fprintf(fid, '32768点FFT分析结果\n');
    fprintf(fid, '====================\n\n');
    fprintf(fid, '参数:\n');
    fprintf(fid, '  采样率: %.2f MHz\n', fs/1e6);
    fprintf(fid, '  FFT点数: %d\n', N);
    fprintf(fid, '  频率分辨率: %.4f Hz\n', df);
    fprintf(fid, '\n目标:\n');
    fprintf(fid, '  频率: %d Hz\n', target_freq);
    fprintf(fid, '  幅度: %d mVpp\n', target_vpp);
    fprintf(fid, '\n结果:\n');
    fprintf(fid, '  峰值bin: %d\n', peak_bin);
    fprintf(fid, '  峰值频率: %.2f Hz\n', peak_freq);
    fprintf(fid, '  精确频率: %.2f Hz\n', exact_freq);
    fprintf(fid, '  频率误差: %.2f Hz\n', freq_error);
    fprintf(fid, '  幅度: %.2f mVpp\n', recovered_vpp);
    fprintf(fid, '  幅度误差: %.2f mVpp\n', abs(recovered_vpp - target_vpp));
    fprintf(fid, '\n精度判定:\n');
    if freq_error <= 100
        fprintf(fid, '  频率精度: PASS\n');
    else
        fprintf(fid, '  频率精度: FAIL\n');
    end
    if abs(recovered_vpp - target_vpp) <= 5
        fprintf(fid, '  幅度精度: PASS\n');
    else
        fprintf(fid, '  幅度精度: FAIL\n');
    end
    fclose(fid);
    fprintf('  结果已保存: %s\n', result_file);
    
    fprintf('\n');
    fprintf('=' * ones(1, 70));
    fprintf('\n');
    fprintf('分析完成!\n');
    fprintf('=' * ones(1, 70));
    fprintf('\n');
end
