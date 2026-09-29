% run_spectrum.m - 调用 plot_ila_spectrum 函数
% 确保工作目录正确
addpath('C:\Users\24307\Desktop\FPGA_windows\matlab\2026_G\code');

csv_path = 'C:\Users\24307\Desktop\FPGA_windows\Vivado\result\2026_G\hw\ila_data.csv';

if ~exist(csv_path, 'file')
    fprintf('错误: CSV 文件不存在: %s\n', csv_path);
    return;
end

% 调用主函数
plot_ila_spectrum(csv_path, ...
    'FigDir', 'C:\Users\24307\Desktop\FPGA_windows\matlab\2026_G\figure', ...
    'ResultDir', 'C:\Users\24307\Desktop\FPGA_windows\matlab\2026_G\result', ...
    'TargetFreq', 200000, ...
    'TargetVpp', 500);

fprintf('\n[完成] 图片已保存到 figure 目录\n');
