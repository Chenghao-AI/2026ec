% plot_ila_simple.m
% 简化频谱图生成 - 用户 GUI 抓取的 ILA CSV
clear; clc; close all;

% 参数
csv_path = 'C:\Users\24307\Desktop\FPGA_windows\Vivado\result\iladata.csv';
FS = 4e6;
FFT_N = 8192;
DF = FS / FFT_N;  % 488.28125 Hz

% 读取
fid = fopen(csv_path, 'r');
fgetl(fid);  % header 1
fgetl(fid);  % header 2
raw = textscan(fid, '%d%d%d%d%d%s%s%s', 'Delimiter', ',');
fclose(fid);

% 提取数据
mag = double(raw{4});       % decimal
bin_idx = double(raw{5});   % decimal
valid_dec = raw{6};
adc_raw = raw{7};

% ADC: 12-bit signed
adc = hex2dec(adc_raw);
adc(adc >= 2048) = adc(adc >= 2048) - 4096;
adc_mv = adc * (1000 / 4096);

% valid
valid = zeros(size(mag));
for i = 1:length(valid_dec)
    s = valid_dec{i};
    if ~isempty(s)
        valid(i) = hex2dec(s);
    end
end

% 提取频谱数据
valid_mask = valid == 1;
fprintf('valid=1 点数: %d / %d\n', sum(valid_mask), length(valid));

bins_all = bin_idx(valid_mask);
mags_all = mag(valid_mask);
freqs_khz = bins_all * DF / 1e3;

% 找峰值
[peak_mag, peak_loc] = max(mags_all);
peak_bin = bins_all(peak_loc);
peak_freq = freqs_khz(peak_loc);

fprintf('\n===== 粗峰值 =====\n');
fprintf('峰值 bin: %d\n', peak_bin);
fprintf('峰值频率: %.3f kHz (%.2f Hz)\n', peak_freq, peak_freq*1e3);
fprintf('峰值 mag: %d\n', peak_mag);

% 5 点抛物线插值
fprintf('\n===== 5 点抛物线插值 =====\n');
nearby_mags = zeros(5,1);
for off = -2:2
    b = peak_bin + off;
    idx = find(bins_all == b, 1);
    if ~isempty(idx)
        nearby_mags(off+3) = mags_all(idx);
    else
        nearby_mags(off+3) = 0;
    end
end
fprintf('5 点 mag: ');
fprintf('%d ', nearby_mags);
fprintf('\n');

% 5 点最小二乘抛物线拟合
% y = a*k^2 + b*k + c, k = -2..2
ks = (-2:2)';
K = [ks.^2, ks, ones(5,1)];
coef = K \ nearby_mags;
a = coef(1); b = coef(2); c = coef(3);
fprintf('拟合系数: a=%.2f, b=%.2f, c=%.2f\n', a, b, c);

% 抛物线顶点
if a < 0
    delta = -b / (2*a);
    interp_bin = peak_bin + delta;
    fprintf('顶点偏移: delta = %.4f\n', delta);
    fprintf('插值后 bin: %.4f\n', interp_bin);
    fprintf('插值后频率: %.4f kHz (%.2f Hz)\n', interp_bin*DF/1e3, interp_bin*DF);
    fprintf('相比 200kHz 误差: %.2f Hz\n', interp_bin*DF - 200000);
    fprintf('顶点 mag (拟合): %.2f\n', c - b^2/(4*a));
else
    fprintf('a >= 0, 抛物线开口朝上, 无有效顶点\n');
end

% 3 点抛物线插值
y_m1 = nearby_mags(2);
y_0 = nearby_mags(3);
y_p1 = nearby_mags(4);
denom = 2*(y_m1 - 2*y_0 + y_p1);
if denom ~= 0
    delta3 = (y_m1 - y_p1) / denom;
    interp_bin3 = peak_bin + delta3;
    fprintf('\n===== 3 点抛物线插值 =====\n');
    fprintf('delta = %.4f, interpolated bin = %.4f\n', delta3, interp_bin3);
    fprintf('frequency = %.4f kHz, error = %.2f Hz\n', interp_bin3*DF/1e3, interp_bin3*DF - 200000);
end

% ===== 频谱图 =====
figure('Position', [100, 100, 1400, 900]);

% 子图 1: 完整频谱
subplot(2, 2, 1);
plot(freqs_khz, mags_all, 'b.-', 'MarkerSize', 3);
xlabel('Frequency (kHz)');
ylabel('Magnitude (LSB)');
title(sprintf('Full Spectrum (0 ~ %.2f MHz)', FS/2/1e6));
grid on;
xlim([0 FS/2/1e3]);
hold on;
plot(peak_freq, peak_mag, 'r*', 'MarkerSize', 14, 'LineWidth', 2);
hold off;

% 子图 2: 局部放大 (160 ~ 200 kHz)
subplot(2, 2, 2);
zoom_mask = freqs_khz >= 160 & freqs_khz <= 200;
plot(freqs_khz(zoom_mask), mags_all(zoom_mask), 'b.-', 'MarkerSize', 10, 'LineWidth', 1.5);
hold on;
plot(peak_freq, peak_mag, 'r*', 'MarkerSize', 15, 'LineWidth', 2);
if exist('interp_bin', 'var')
    plot(interp_bin*DF/1e3, c - b^2/(4*a), 'gv', 'MarkerSize', 12, 'LineWidth', 2);
end
xlabel('Frequency (kHz)');
ylabel('Magnitude (LSB)');
title(sprintf('Peak Region: Coarse bin=%d, Parabolic bin=%.2f', peak_bin, interp_bin));
grid on;
xlim([160 200]);

% 子图 3: 时域波形
subplot(2, 2, 3);
n_show = min(500, length(adc_mv));
t_us = (0:n_show-1) / FS * 1e6;
plot(t_us, adc_mv(1:n_show), 'b-', 'LineWidth', 0.5);
xlabel('Time (us)');
ylabel('ADC (mV)');
title(sprintf('ADC Time Domain (DC=%.1f mV, range=%.0f mV)', mean(adc_mv), max(adc_mv)-min(adc_mv)));
grid on;

% 子图 4: 5 点抛物线拟合
subplot(2, 2, 4);
ks_plot = (-2.5:0.01:2.5)';
y_fit = a*ks_plot.^2 + b*ks_plot + c;
plot(ks, nearby_mags, 'bo', 'MarkerSize', 10, 'LineWidth', 2);
hold on;
plot(ks_plot, y_fit, 'r-', 'LineWidth', 1.5);
plot(delta, c - b^2/(4*a), 'gv', 'MarkerSize', 15, 'LineWidth', 2);
xlabel('Bin offset from peak');
ylabel('Magnitude (LSB)');
title(sprintf('5-Point Parabolic Fit (delta=%.4f)', delta));
grid on;
legend('Data', 'Parabolic fit', 'Vertex', 'Location', 'best');

% 总标题
annotation('textbox', [0.3 0.95 0.4 0.04], ...
    'String', sprintf('ILA Spectrum (fs=%.1f MHz, N=%d, df=%.2f Hz)', ...
    FS/1e6, FFT_N, DF), ...
    'EdgeColor', 'none', 'FontSize', 12, 'FontWeight', 'bold', 'HorizontalAlignment', 'center');

% 保存图片
fig_path = 'C:\Users\24307\Desktop\FPGA_windows\matlab\2026_G\figure\ila_spectrum_GUI.png';
saveas(gcf, fig_path);
fprintf('\n图片已保存: %s\n', fig_path);

% 报告
fprintf('\n===== 频谱分析报告 =====\n');
fprintf('输入信号: 200 kHz, 500 mVpp, 0V offset\n');
fprintf('期望频率: 200.000 kHz\n');
fprintf('粗峰值 bin: %d, 粗频率: %.3f kHz\n', peak_bin, peak_freq);
if exist('interp_bin', 'var')
    fprintf('5 点抛物线插值 bin: %.4f, 频率: %.4f kHz\n', interp_bin, interp_bin*DF/1e3);
    fprintf('频率误差: %.2f Hz\n', interp_bin*DF - 200000);
end
fprintf('峰值 mag: %d LSB\n', peak_mag);
