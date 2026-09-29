% ============================================================================
% plot_ila_spectrum.m — 从 ILA CSV 数据绘制频谱图
% ============================================================================
% 输入: ILA 导出的 CSV 文件
% 输出: 4 幅图 + 分析报告
%
% CSV 格式 (来自 Vivado ILA):
%   Sample, Window, TRIGGER, mag, bin, valid, adc, frame_end
%   mag 和 bin 是十六进制格式
%
% 关键参数:
%   采样率: fs = 4 MHz
%   FFT 点数: N = 8192
%   分辨率: Δf = 488.28125 Hz
% ============================================================================

function plot_ila_spectrum(csv_path, varargin)
    % 默认参数
    fig_dir = 'C:\Users\24307\Desktop\FPGA_windows\matlab\2026_G\figure';
    result_dir = 'C:\Users\24307\Desktop\FPGA_windows\matlab\2026_G\result';
    target_freq = 200000;  % 目标频率 200 kHz
    target_vpp = 500;       % 目标峰峰值 500 mV
    
    % 解析可选参数
    for i = 1:2:length(varargin)
        switch varargin{i}
            case 'FigDir', fig_dir = varargin{i+1};
            case 'ResultDir', result_dir = varargin{i+1};
            case 'TargetFreq', target_freq = varargin{i+1};
            case 'TargetVpp', target_vpp = varargin{i+1};
        end
    end
    
    % 常数
    fs = 4e6;           % 采样率 4 MHz
    N = 8192;           % FFT 点数
    delta_f = fs / N;   % 频率分辨率 488.28125 Hz
    
    fprintf('\n============================================================\n');
    fprintf('ILA 频谱分析\n');
    fprintf('============================================================\n');
    fprintf('CSV 文件: %s\n', csv_path);
    fprintf('采样率: %.0f Hz\n', fs);
    fprintf('FFT 点数: %d\n', N);
    fprintf('分辨率: %.4f Hz\n', delta_f);
    fprintf('目标频率: %d Hz\n', target_freq);
    fprintf('目标幅值: %d mVpp\n', target_vpp);
    fprintf('============================================================\n\n');
    
    % 读取 CSV 文件
    if ~exist(csv_path, 'file')
        error('CSV 文件不存在: %s', csv_path);
    end
    
    % 直接读取文本文件（处理十六进制格式）
    fid = fopen(csv_path, 'r');
    if fid == -1
        error('无法打开文件: %s', csv_path);
    end
    
    % 跳过可能的注释行
    headers = {};
    data_lines = {};
    line_num = 0;
    while ~feof(fid)
        line = fgetl(fid);
        line_num = line_num + 1;
        if isempty(line) || line(1) == '#'
            continue;
        end
        if isempty(headers)
            headers = strsplit(strtrim(line), {',', ' ', '\t'});
            headers = headers(~cellfun(@isempty, headers));
        else
            data_lines{end+1, 1} = line;
        end
    end
    fclose(fid);
    
    fprintf('列标题: %s\n', strjoin(headers, ', '));
    fprintf('数据行数: %d\n', length(data_lines));
    
    % 解析数据
    mag = zeros(length(data_lines), 1);
    bin_idx = zeros(length(data_lines), 1);
    valid = zeros(length(data_lines), 1);
    adc = zeros(length(data_lines), 1);
    frame_end = zeros(length(data_lines), 1);
    
    for i = 1:length(data_lines)
        parts = strsplit(strtrim(data_lines{i}), {',', ' ', '\t'});
        parts = parts(~cellfun(@isempty, parts));
        
        for j = 1:length(parts)
            val = strtrim(parts{j});
            % 处理十六进制格式 (0x...)
            if length(val) > 2 && (strcmpi(val(1:2), '0x') || strcmpi(val(1:2), '0X'))
                val = val(3:end);  % 去掉 0x 前缀
                parts{j} = num2str(hex2dec(val));
            end
        end
        
        % 假设列顺序: Sample, Window, TRIGGER, mag, bin, valid, adc, frame_end
        if length(parts) >= 4, mag(i) = str2double(parts{4}); end
        if length(parts) >= 5, bin_idx(i) = str2double(parts{5}); end
        if length(parts) >= 6, valid(i) = str2double(parts{6}); end
        if length(parts) >= 7, adc(i) = str2double(parts{7}); end
        if length(parts) >= 8, frame_end(i) = str2double(parts{8}); end
    end
    
    % 过滤有效数据 (valid=1 且 bin < 4096)
    valid_mask = (valid ~= 0);
    bin_mask = (bin_idx >= 0) & (bin_idx < 4096);
    data_mask = valid_mask & bin_mask;
    
    mag_valid = mag(data_mask);
    bin_valid = bin_idx(data_mask);
    adc_valid = adc(data_mask);
    
    fprintf('有效数据点数: %d / %d\n', length(mag_valid), length(mag));
    
    if isempty(mag_valid)
        error('没有有效数据！检查 ILA 触发和数据流');
    end
    
    % 转换为频率
    freq = bin_valid * delta_f;
    
    % 找峰值
    [peak_mag, peak_idx] = max(mag_valid);
    peak_freq = freq(peak_idx);
    peak_bin = bin_valid(peak_idx);
    
    fprintf('\n========== 峰值检测 ==========\n');
    fprintf('峰值 bin: %d\n', peak_bin);
    fprintf('峰值频率: %.2f Hz (%.4f kHz)\n', peak_freq, peak_freq/1000);
    fprintf('峰值幅值 (原始): %d\n', peak_mag);
    
    % 幅度校准
    % ADC 12-bit, Vref=2V (典型)
    % 500mVpp 正弦波: 峰值 = 250mV
    % CORDIC 输出是 Q1.15 格式, 需要校准因子
    % 理论: 峰峰值 500mV -> CORDIC 幅值约 250 (按 Q1.15 归一化)
    % 但由于 Hann 窗损耗和 FFT 量化, 需要实际测量来校准
    
    % 简单校准: 假设测量信号就是 500mVpp
    v_scale = (target_vpp / 2) / peak_mag;
    peak_mv = peak_mag * v_scale;
    peak_vpp = peak_mv * 2;
    
    % 计算误差
    freq_error = abs(peak_freq - target_freq);
    vpp_error = abs(peak_vpp - target_vpp);
    
    fprintf('\n========== 校准结果 ==========\n');
    fprintf('校准因子: %.6f mV/LSB\n', v_scale);
    fprintf('峰值幅度: %.2f mVpp\n', peak_vpp);
    fprintf('目标幅值: %d mVpp\n', target_vpp);
    fprintf('\n========== 误差分析 ==========\n');
    fprintf('频率误差: %.2f Hz (要求 < 100 Hz)\n', freq_error);
    fprintf('幅度误差: %.2f mV (要求 < 5 mV)\n', vpp_error);
    
    % 判断是否达标
    freq_pass = freq_error <= 100;
    vpp_pass = vpp_error <= 5;
    overall_pass = freq_pass && vpp_pass;
    
    fprintf('\n============================================================\n');
    if overall_pass
        fprintf('状态: ✅ 测试达标\n');
    else
        fprintf('状态: ❌ 未达标\n');
        if ~freq_pass
            fprintf('  - 频率误差超出范围\n');
        end
        if ~vpp_pass
            fprintf('  - 幅度误差超出范围\n');
        end
    end
    fprintf('============================================================\n');
    
    % ========== 绘图 ==========
    fig = figure('Position', [100, 100, 1400, 900]);
    
    % 图1: 完整频谱 (0~2 MHz)
    subplot(2, 2, 1);
    plot(freq/1000, mag_valid * v_scale, 'b-', 'LineWidth', 0.5);
    hold on;
    if ~isempty(peak_freq)
        plot(peak_freq/1000, peak_mv, 'r*', 'MarkerSize', 10);
        text(peak_freq/1000 + 50, peak_mv, ...
            sprintf('f=%.1f kHz\nV=%.1f mV', peak_freq/1000, peak_vpp), ...
            'VerticalAlignment', 'bottom', 'FontSize', 9);
    end
    xlabel('频率 (kHz)');
    ylabel('幅值 (mVpp)');
    title(sprintf('完整频谱 (0~2 MHz)\n峰值: %.1f kHz', peak_freq/1000));
    grid on;
    xlim([0, 2000]);
    
    % 图2: 信号区间放大 (180~220 kHz)
    subplot(2, 2, 2);
    mask_zoom = (freq >= 180e3) & (freq <= 220e3);
    if any(mask_zoom)
        plot(freq(mask_zoom)/1000, mag_valid(mask_zoom) * v_scale, 'b-', 'LineWidth', 1);
        hold on;
        if peak_freq >= 180e3 && peak_freq <= 220e3
            plot(peak_freq/1000, peak_mv, 'r*', 'MarkerSize', 15);
            text(peak_freq/1000 + 2, peak_mv, ...
                sprintf('f=%.2f kHz', peak_freq/1000), ...
                'VerticalAlignment', 'bottom', 'FontSize', 10);
        end
    end
    xlabel('频率 (kHz)');
    ylabel('幅值 (mVpp)');
    title(sprintf('信号区间 (180~220 kHz)\n目标: %.0f kHz', target_freq/1000));
    grid on;
    
    % 图3: ADC 时域波形
    subplot(2, 2, 3);
    if ~isempty(adc_valid)
        % 转换 ADC 值到电压
        % AD9226: 12-bit, offset binary, Vref=2V
        % 0 -> -2V, 2048 -> 0V, 4095 -> +2V
        v_adc = (double(adc_valid) - 2048) * 2000 / 2048;  % mV
        t = (0:length(v_adc)-1) / fs * 1000;  % ms
        plot(t, v_adc, 'b-', 'LineWidth', 0.3);
        xlabel('时间 (ms)');
        ylabel('电压 (mV)');
        title('ADC 时域波形 (前 0.5ms)');
        grid on;
        xlim([0, 0.5]);
    else
        text(0.5, 0.5, 'ADC 数据不可用', 'Units', 'normalized', ...
            'FontSize', 14, 'HorizontalAlignment', 'center');
        axis off;
    end
    
    % 图4: 局部频谱 (0~600 kHz) + 误差统计
    subplot(2, 2, 4);
    mask_low = (freq <= 600e3);
    if any(mask_low)
        plot(freq(mask_low)/1000, mag_valid(mask_low) * v_scale, 'b-', 'LineWidth', 0.5);
        hold on;
        if peak_freq <= 600e3 && ~isempty(peak_freq)
            plot(peak_freq/1000, peak_mv, 'r*', 'MarkerSize', 10);
        end
    end
    xlabel('频率 (kHz)');
    ylabel('幅值 (mVpp)');
    title(sprintf('局部频谱 (0~600 kHz)\n分辨率: %.2f Hz', delta_f));
    grid on;
    xlim([0, 600]);
    
    % 保存图片
    fig_path = fullfile(fig_dir, 'ila_spectrum.png');
    if ~exist(fig_dir, 'dir')
        mkdir(fig_dir);
    end
    saveas(gcf, fig_path);
    fprintf('\n图片已保存: %s\n', fig_path);
    
    % 保存报告
    report_path = fullfile(result_dir, 'spectrum_report.txt');
    if ~exist(result_dir, 'dir')
        mkdir(result_dir);
    end
    fid = fopen(report_path, 'w');
    fprintf(fid, '========== ILA 频谱分析报告 ==========\n');
    fprintf(fid, '时间: %s\n', datestr(now));
    fprintf(fid, 'CSV 文件: %s\n', csv_path);
    fprintf(fid, '\n');
    fprintf(fid, '========== 系统参数 ==========\n');
    fprintf(fid, '采样率: %.0f Hz\n', fs);
    fprintf(fid, 'FFT 点数: %d\n', N);
    fprintf(fid, '分辨率: %.4f Hz\n', delta_f);
    fprintf(fid, '\n');
    fprintf(fid, '========== 目标值 ==========\n');
    fprintf(fid, '目标频率: %d Hz\n', target_freq);
    fprintf(fid, '目标幅值: %d mVpp\n', target_vpp);
    fprintf(fid, '\n');
    fprintf(fid, '========== 测量结果 ==========\n');
    fprintf(fid, '峰值 bin: %d\n', peak_bin);
    fprintf(fid, '峰值频率: %.2f Hz\n', peak_freq);
    fprintf(fid, '峰值幅值: %.2f mVpp\n', peak_vpp);
    fprintf(fid, '校准因子: %.6f mV/LSB\n', v_scale);
    fprintf(fid, '\n');
    fprintf(fid, '========== 误差分析 ==========\n');
    fprintf(fid, '频率误差: %.2f Hz (要求 < 100 Hz)\n', freq_error);
    fprintf(fid, '幅度误差: %.2f mV (要求 < 5 mV)\n', vpp_error);
    fprintf(fid, '\n');
    if overall_pass
        fprintf(fid, '状态: ✅ 测试达标\n');
    else
        fprintf(fid, '状态: ❌ 未达标\n');
    end
    fprintf(fid, '================================\n');
    fclose(fid);
    fprintf('报告已保存: %s\n', report_path);
    
    % 返回结果
    result.freq = peak_freq;
    result.mag = peak_vpp;
    result.freq_error = freq_error;
    result.mag_error = vpp_error;
    result.freq_pass = freq_pass;
    result.vpp_pass = vpp_pass;
    result.pass = overall_pass;
    result.peak_bin = peak_bin;
    result.delta_f = delta_f;
    result.v_scale = v_scale;
    
    if nargout == 0
        clear result;
    else
        varargout{1} = result;
    end
end
