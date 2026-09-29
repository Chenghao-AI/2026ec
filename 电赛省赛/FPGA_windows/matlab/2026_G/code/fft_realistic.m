% fft_realistic.m — 模拟 Hann 窗 + FFT，模拟 xfft scaled 输出
% 用真实 ADC 数据做 FFT，对比 FPGA CORDIC 输出
adc_path = 'C:\Users\24307\Desktop\FPGA_windows\adc_timeseries.csv';
data = csvread(adc_path, 1);
adc = data(:, 2);

N = 8192;
fs = 4e6;
df = fs / N;
n_idx = (0:N-1)';

% Hann window
w = 0.5 * (1 - cos(2*pi*n_idx/N));
% 12-bit quantization (mirror FPGA)
adc_q = round(adc);
% Apply Hann
x_w = adc_q .* w;

% FFT (scaled mode matches FPGA)
X = fft(x_w);
mag_full = abs(X);

% Take first N/2 bins
mag_half = mag_full(1:N/2);
freqs = (0:N/2-1) * df;

% Find peak
[peak_mag, idx] = max(mag_half);
peak_bin = idx - 1;  % 0-indexed
peak_freq = peak_bin * df;

fprintf('\n=== Realistic simulation (Hann + 12-bit quant + FFT) ===\n');
fprintf('Peak mag: %.2f\n', peak_mag);
fprintf('Peak bin: %d\n', peak_bin);
fprintf('Peak freq: %.4f Hz (%.4f kHz)\n', peak_freq, peak_freq/1000);

% Print bins around peak
fprintf('\nMagnitudes bin 405-415 (200 kHz area):\n');
for b = 405:415
    fprintf('  bin %d: %.2f\n', b, mag_half(b+1));
end

% Also print bins 340-360 (171 kHz area)
fprintf('\nMagnitudes bin 340-360 (171 kHz area):\n');
for b = 340:360
    fprintf('  bin %d: %.2f\n', b, mag_half(b+1));
end

% Compare with CORDIC outputs
fprintf('\n=== Comparison with CORDIC (FPGA) ===\n');
fprintf('FPGA bin 351 mag = 24146\n');
fprintf('Sim bin 351 mag = %.2f\n', mag_half(352));
fprintf('FPGA bin 410 mag ~ 631\n');
fprintf('Sim bin 410 mag = %.2f\n', mag_half(411));

% Also try to find global max ratio
fprintf('\nRatio: Sim_bin_351/Sim_bin_410 = %.4f\n', mag_half(352)/mag_half(411));
fprintf('Ratio: FPGA_351/FPGA_410 = %.4f\n', 24146/631);

exit
