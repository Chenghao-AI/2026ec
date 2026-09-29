% ============================================================================
% analyze_ila_data.m — 分析 ILA CSV 数据，提取频谱信息
% ============================================================================
% 功能:
%   1. 读取 ILA CSV 文件
%   2. 提取频谱数据 (mag, bin)
%   3. 计算峰值频率和幅度
%   4. 与目标值对比
%   5. 输出分析报告
%
% 参数:
%   csv_path - ILA CSV 文件路径
%   target_freq - 目标频率 (Hz), 默认 200000 Hz
%   target_vpp - 目标峰峰值 (mV), 默认 500 mV
% ============================================================================

function [result, data] = analyze_ila_data(csv_path, target_freq, target_vpp)
    % 默认参数
    if nargin < 2, target_freq = 200000; end
    if nargin < 3, target_vpp = 500; end
    
    % 常数定义
    FS = 4e6;           % 采样率 4 MHz
    FFT_N = 8192;       % FFT 点数
    DELTA_F = FS / FFT_N;  % 分辨率 488.28125 Hz
    
    % 输出路径
    fig_dir = 'C:\Users\24307\Desktop\FPGA_windows\matlab\2026_G\figure';
    result_dir = 'C:\Users\24307\Desktop\FPGA_windows\matlab\2026_G\result';
    
    fprintf('\n========== ILA 数据分析 ==========\n');
    fprintf('CSV 文件: %s\n', csv_path);
    fprintf('采样率: %.0f Hz\n', FS);
    fprintf('FFT 点数: %d\n', FFT_N);
    fprintf('分辨率: %.4f Hz\n', DELTA_F);
    fprintf('目标频率: %d Hz\n', target_freq);
    fprintf('目标幅值: %d mVpp\n', target_vpp);
    fprintf('================================\n\n');
    
    % 读取 CSV
    if ~exist(csv_path, 'file')
        error('CSV 文件不存在: %s', csv_path);
    end
    
    opts = detectImportOptions(csv_path);
    data_table = readtable(csv_path, opts);
    varNames = data_table.Properties.VariableNames;
    fprintf('CSV 列: %s\n', strjoin(varNames, ', '));
    
    % 提取 mag 和 bin
    [mag_col, ~] = find_column(data_table, 'mag');
    [bin_col, ~] = find_column(data_table, 'bin');
    [valid_col, has_valid] = find_column(data_table, 'valid');
    [adc_col, has_adc] = find_column(data_table, 'adc');
    [frame_col, has_frame] = find_column(data_table, 'frame');
    
    % 提取数据
    mag_raw = data_table{:, mag_col};
    bin_raw = data_table{:, bin_col};
    
    % 处理十六进制格式
    if iscell(mag_raw{1})
        mag = zeros(length(mag_raw), 1);
        for i = 1:length(mag_raw)
            hex_str = strrep(mag_raw{i}, '0x', '');
            hex_str = strrep(hex_str, '0X', '');
            mag(i) = hex2dec(hex_str);
        end
    else
        mag = double(mag_raw);
    end
    
    if iscell(bin_raw{1})
        bin = zeros(length(bin_raw), 1);
        for i = 1:length(bin_raw)
            hex_str = strrep(bin_raw{i}, '0x', '');
            hex_str = strrep(hex_str, '0X', '');
            bin(i) = hex2dec(hex_str);
        end
    else
        bin = double(bin_raw);
    end
    
    % 提取有效数据
    if has_valid
        valid_raw = data_table{:, valid_col};
        if iscell(valid_raw{1})
            valid = zeros(length(valid_raw), 1);
            for i = 1:length(valid_raw)
                hex_str = strrep(valid_raw{i}, '0x', '');
                valid(i) = str2double(hex_str);
            end
        else
            valid = double(valid_raw);
        end
        valid_mask = (valid ~= 0);
    else
        valid_mask = true(size(mag));
    end
    
    % 过滤 bin 范围 (0~4095)
    bin_mask = (bin >= 0) & (bin < 4096);
    data_mask = valid_mask & bin_mask;
    
    mag = mag(data_mask);
    bin = bin(data_mask);
    
    fprintf('有效数据点数: %d / %d\n', length(mag), length(data_table{:, 1}));
    
    % 计算频率
    freq = double(bin) * DELTA_F;
    
    % ========== 峰值检测 ==========
    % 找最大幅值
    [peak_mag, peak_idx] = max(mag);
    peak_freq = freq(peak_idx);
    peak_bin = bin(peak_idx);
    
    fprintf('\n峰值检测结果:\n');
    fprintf('  峰值 bin: %d\n', peak_bin);
    fprintf('  峰值频率: %.2f Hz (%.4f kHz)\n', peak_freq, peak_freq/1000);
    fprintf('  峰值幅值 (原始): %d\n', peak_mag);
    
    % ========== 幅度校准 ==========
    % ADC 12-bit: 0~4095 对应 0~2V (典型)
    % 500mVpp 正弦波: 峰值 = 250mV
    % 理论 FFT 幅值: 对于 12-bit 量化，Vpp=500mV 对应的 ADC LSB 数
    % ADC LSB = 2V / 4096 = 0.488mV
    % 500mV / 0.488mV ≈ 1024 LSB (峰峰值)
    % 峰值 = 512 LSB
    % 但 Hann 窗会有损耗
    
    % 使用理论值计算校准因子
    % 理想情况下: 500mVpp / 2 = 250mV 峰值对应某个 mag 值
    % 校准因子 = 250 / peak_mag (假设 peak_mag 来自 500mVpp 信号)
    
    % 但由于 FFT 和 Hann 窗的影响，需要实际标定
    % 这里使用目标值反推校准
    v_calibration = 1.0;  % 初始校准
    mag_mv = double(mag) * v_calibration;
    peak_mv = peak_mag * v_calibration;
    
    fprintf('\n幅度分析:\n');
    fprintf('  原始峰值: %.2f mVpp\n', peak_mv * 2);
    fprintf('  目标幅值: %d mVpp\n', target_vpp);
    
    % ========== 误差计算 ==========
    freq_error = abs(peak_freq - target_freq);
    vpp_error = abs(peak_mv * 2 - target_vpp);
    
    fprintf('\n========== 误差分析 ==========\n');
    fprintf('目标频率: %d Hz\n', target_freq);
    fprintf('测量频率: %.2f Hz\n', peak_freq);
    fprintf('频率误差: %.2f Hz\n', freq_error);
    fprintf('要求: < 100 Hz\n');
    fprintf('\n');
    fprintf('目标幅值: %d mVpp\n', target_vpp);
    fprintf('测量幅值: %.2f mVpp\n', peak_mv * 2);
    fprintf('幅度误差: %.2f mV\n', vpp_error);
    fprintf('要求: < 5 mV\n');
    fprintf('==============================\n\n');
    
    % 判断是否达标
    freq_pass = freq_error <= 100;
    vpp_pass = vpp_error <= 5;
    
    if freq_pass && vpp_pass
        fprintf('状态: ✅ 测试达标\n\n');
    else
        fprintf('状态: ❌ 未达标\n');
        if ~freq_pass
            fprintf('  - 频率误差超出范围 (%.2f Hz > 100 Hz)\n', freq_error);
        end
        if ~vpp_pass
            fprintf('  - 幅度误差超出范围 (%.2f mV > 5 mV)\n', vpp_error);
        end
        fprintf('\n');
    end
    
    % ========== 保存报告 ==========
    report_path = fullfile(result_dir, 'analysis_result.txt');
    fid = fopen(report_path, 'w');
    fprintf(fid, '========== ILA 频谱分析报告 ==========\n');
    fprintf(fid, '时间: %s\n', datestr(now));
    fprintf(fid, 'CSV 文件: %s\n', csv_path);
    fprintf(fid, '\n');
    fprintf(fid, '========== 系统参数 ==========\n');
    fprintf(fid, '采样率: %.0f Hz\n', FS);
    fprintf(fid, 'FFT 点数: %d\n', FFT_N);
    fprintf(fid, '分辨率: %.4f Hz\n', DELTA_F);
    fprintf(fid, '\n');
    fprintf(fid, '========== 目标值 ==========\n');
    fprintf(fid, '目标频率: %d Hz\n', target_freq);
    fprintf(fid, '目标幅值: %d mVpp\n', target_vpp);
    fprintf(fid, '\n');
    fprintf(fid, '========== 测量结果 ==========\n');
    fprintf(fid, '峰值 bin: %d\n', peak_bin);
    fprintf(fid, '峰值频率: %.2f Hz\n', peak_freq);
    fprintf(fid, '峰值幅值: %.2f mVpp\n', peak_mv * 2);
    fprintf(fid, '\n');
    fprintf(fid, '========== 误差分析 ==========\n');
    fprintf(fid, '频率误差: %.2f Hz (要求 < 100 Hz)\n', freq_error);
    fprintf(fid, '幅度误差: %.2f mV (要求 < 5 mV)\n', vpp_error);
    fprintf(fid, '\n');
    if freq_pass && vpp_pass
        fprintf(fid, '状态: ✅ 测试达标\n');
    else
        fprintf(fid, '状态: ❌ 未达标\n');
    end
    fprintf(fid, '================================\n');
    fclose(fid);
    fprintf('报告已保存: %s\n', report_path);
    
    % ========== 返回结果 ==========
    result.freq = peak_freq;
    result.mag = peak_mv * 2;
    result.freq_error = freq_error;
    result.mag_error = vpp_error;
    result.freq_pass = freq_pass;
    result.vpp_pass = vpp_pass;
    result.pass = freq_pass && vpp_pass;
    result.peak_bin = peak_bin;
    result.delta_f = DELTA_F;
    result.fs = FS;
    result.fft_n = FFT_N;
    result.mag_raw = mag;
    result.bin = bin;
    result.freq_axis = freq;
    
    % ========== 绘图 ==========
    plot_spectrum_results(result, fig_dir);
    
    fprintf('\n========== 分析完成 ==========\n\n');
end

% ========== 辅助函数 ==========
function [colName, found] = find_column(data_table, keyword)
    varNames = data_table.Properties.VariableNames;
    found = false;
    colName = '';
    
    for i = 1:length(varNames)
        if contains(lower(varNames{i}), lower(keyword))
            colName = varNames{i};
            found = true;
            return;
        end
    end
end

function plot_spectrum_results(result, fig_dir)
    % 创建频谱图
    figure('Position', [100, 100, 1400, 900]);
    
    % 图1: 完整频谱
    subplot(2, 3, 1);
    freq_khz = result.freq_axis / 1000;
    plot(freq_khz, result.mag_raw, 'b-', 'LineWidth', 0.5);
    hold on;
    plot(result.freq/1000, result.mag/2, 'r*', 'MarkerSize', 12);
    xlabel('频率 (kHz)');
    ylabel('幅值 (原始)');
    title(sprintf('完整频谱 (0~2 MHz)\n峰值: %.1f kHz', result.freq/1000));
    grid on;
    xlim([0, 2000]);
    
    % 图2: 目标区域放大
    subplot(2, 3, 2);
    target = 200000;
    mask = (result.freq_axis >= target - 50e3) & (result.freq_axis <= target + 50e3);
    if any(mask)
        plot(result.freq_axis(mask)/1000, result.mag_raw(mask), 'b-', 'LineWidth', 1);
        hold on;
        plot(result.freq/1000, result.mag/2, 'r*', 'MarkerSize', 15);
        xlabel('频率 (kHz)');
        ylabel('幅值 (原始)');
        title(sprintf('目标区域 (%.1f±50 kHz)', target/1000));
        grid on;
    end
    
    % 图3: 误差显示
    subplot(2, 3, 3);
    bar_names = {'频率误差\n(Hz)', '幅度误差\n(mV)'};
    errors = [result.freq_error, result.mag_error];
    thresholds = [100, 5];
    colors = ['r', 'r'];
    if result.freq_pass, colors(1) = 'g'; end
    if result.vpp_pass, colors(2) = 'g'; end
    bar(1:2, errors);
    hold on;
    bar(1:2, thresholds, 'FaceAlpha', 0.3);
    xticklabels(bar_names);
    ylabel('误差');
    title('误差分析 (绿=达标, 红=未达标)');
    grid on;
    for i = 1:2
        text(i, errors(i) + 2, sprintf('%.2f', errors(i)), 'HorizontalAlignment', 'center');
    end
    
    % 图4: 峰值统计
    subplot(2, 3, 4);
    stats = {sprintf('峰值频率\n%.2f Hz', result.freq), ...
             sprintf('目标频率\n%d Hz', 200000), ...
             sprintf('频率误差\n%.2f Hz', result.freq_error)};
    text(0.5, 0.7, stats{1}, 'FontSize', 12, 'FontWeight', 'bold', ...
         'Color', 'blue', 'Units', 'normalized');
    text(0.5, 0.45, stats{2}, 'FontSize', 11, 'Color', 'black', 'Units', 'normalized');
    text(0.5, 0.2, stats{3}, 'FontSize', 11, ...
         'Color', 'green', 'Units', 'normalized');
    axis off;
    title('频率分析');
    
    % 图5: 幅度统计
    subplot(2, 3, 5);
    stats = {sprintf('峰值幅值\n%.2f mVpp', result.mag), ...
             sprintf('目标幅值\n%d mVpp', 500), ...
             sprintf('幅度误差\n%.2f mV', result.mag_error)};
    text(0.5, 0.7, stats{1}, 'FontSize', 12, 'FontWeight', 'bold', ...
         'Color', 'blue', 'Units', 'normalized');
    text(0.5, 0.45, stats{2}, 'FontSize', 11, 'Color', 'black', 'Units', 'normalized');
    text(0.5, 0.2, stats{3}, 'FontSize', 11, ...
         'Color', 'green', 'Units', 'normalized');
    axis off;
    title('幅度分析');
    
    % 图6: 最终结论
    subplot(2, 3, 6);
    if result.pass
        text(0.5, 0.5, '✅ 测试达标', 'FontSize', 20, 'FontWeight', 'bold', ...
             'Color', 'green', 'Units', 'normalized', 'HorizontalAlignment', 'center');
    else
        text(0.5, 0.5, '❌ 未达标', 'FontSize', 20, 'FontWeight', 'bold', ...
             'Color', 'red', 'Units', 'normalized', 'HorizontalAlignment', 'center');
    end
    axis off;
    title('最终结论');
    
    % 保存图片
    fig_path = fullfile(fig_dir, 'analysis_result.png');
    saveas(gcf, fig_path);
    fprintf('分析图片已保存: %s\n', fig_path);
    
    % 保存数据
    data_path = fullfile(fig_dir, 'spectrum_data.mat');
    save(data_path, 'result');
    fprintf('数据已保存: %s\n', data_path);
    
    close(gcf);
end
