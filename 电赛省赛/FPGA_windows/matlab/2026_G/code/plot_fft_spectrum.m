% ============================================================================
% plot_fft_spectrum.m — 绘制FFT频谱图
% ============================================================================
% 功能:
%   1. 从ILA CSV文件读取FFT数据
%   2. 绘制频谱图
%   3. 保存图表
% ============================================================================

function plot_fft_spectrum(csv_path, output_path)
    %% 参数
    fs = 4e6;           % 采样率 4 MHz
    N = 32768;          % FFT点数 (或根据数据推断)
    df = fs / N;         % 频率分辨率
    
    fprintf('=' * ones(1, 70));
    fprintf('\n');
    fprintf('FFT频谱绘图\n');
    fprintf('=' * ones(1, 70));
    fprintf('\n\n');
    
    %% 读取数据
    fprintf('[1] 读取数据: %s\n', csv_path);
    
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
    
    if isempty(mag_col) || isempty(bin_col)
        error('未找到 mag 或 bin 列');
    end
    
    % 解析数据
    bins = [];
    mags = [];
    
    for i = 3:size(data, 1)
        try
            bin_val = hex2dec(data{i, bin_col}{1});
            mag_val = hex2dec(data{i, mag_col}{1});
            valid = hex2dec(data{i, valid_col}{1});
            
            if valid > 0
                bins = [bins, bin_val];
                mags = [mags, mag_val];
            end
        catch
            % 跳过
        end
    end
    
    fprintf('  有效数据点: %d\n', length(bins));
    
    %% 绘图
    fprintf('\n[2] 绘图...\n');
    
    figure('Position', [100, 100, 1200, 800]);
    
    % 子图1: 完整频谱
    subplot(2, 2, 1);
    plot(bins * df / 1e3, mags, 'b-', 'LineWidth', 1);
    xlabel('频率 (kHz)');
    ylabel('幅度');
    title('完整频谱 (0~1.25 MHz)');
    grid on;
    xlim([0, 1250]);
    
    % 子图2: 目标频率附近 (200kHz)
    subplot(2, 2, 2);
    target_bin = 200000 / df;
    xlim([target_bin - 50, target_bin + 50]);
    plot(bins * df / 1e3, mags, 'b-', 'LineWidth', 1);
    hold on;
    [~, idx] = max(mags);
    plot(bins(idx) * df / 1e3, mags(idx), 'ro', 'MarkerSize', 10);
    xlabel('频率 (kHz)');
    ylabel('幅度');
    title('200kHz附近频谱');
    grid on;
    
    % 子图3: 线性坐标幅度
    subplot(2, 2, 3);
    bar(bins, mags, 1);
    xlabel('Bin');
    ylabel('幅度');
    title('幅度柱状图');
    grid on;
    
    % 子图4: 峰值区域分析
    subplot(2, 2, 4);
    [max_mag, idx] = max(mags);
    peak_bin = bins(idx);
    peak_freq = peak_bin * df;
    
    fprintf('  峰值bin: %d\n', peak_bin);
    fprintf('  峰值频率: %.2f Hz (%.4f kHz)\n', peak_freq, peak_freq/1e3);
    fprintf('  峰值幅度: %d\n', max_mag);
    
    % 显示峰值区域
    center = peak_bin;
    range = 20;
    mask = (bins >= center - range) & (bins <= center + range);
    plot_bins = bins(mask);
    plot_mags = mags(mask);
    
    bar(plot_bins, plot_mags, 1, 'FaceColor', [0.3, 0.5, 0.8]);
    hold on;
    [~, max_idx] = max(plot_mags);
    plot(plot_bins(max_idx), plot_mags(max_idx), 'r*', 'MarkerSize', 15);
    xlabel('Bin');
    ylabel('幅度');
    title(sprintf('峰值区域 (bin %d, %.2f kHz)', peak_bin, peak_freq/1e3));
    grid on;
    
    % 添加频率标注
    text(peak_bin, max_mag, sprintf('Peak: %.2f kHz', peak_freq/1e3), ...
        'VerticalAlignment', 'bottom', 'HorizontalAlignment', 'center');
    
    % 整体标题
    sgtitle(sprintf('FFT频谱分析 (fs=%.1fMHz, N=%d, df=%.2fHz)', fs/1e6, N, df));
    
    %% 保存
    if nargin < 2
        output_path = 'C:\Users\24307\Desktop\FPGA_windows\matlab\2026_G\figure\fft_spectrum.png';
    end
    
    fprintf('\n[3] 保存图表: %s\n', output_path);
    
    % 确保目录存在
    [pathstr, ~, ~] = fileparts(output_path);
    if ~isempty(pathstr) && ~exist(pathstr, 'dir')
        mkdir(pathstr);
    end
    
    saveas(gcf, output_path);
    fprintf('  图表已保存!\n');
    
    close(gcf);
    
    fprintf('\n');
    fprintf('=' * ones(1, 70));
    fprintf('\n');
    fprintf('绘图完成!\n');
    fprintf('=' * ones(1, 70));
    fprintf('\n');
end
