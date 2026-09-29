% fft_verify.m — 干净的 ADC 时域 FFT
adc_path = 'C:\Users\24307\Desktop\FPGA_windows\adc_timeseries.csv';
data = csvread(adc_path, 1);  % skip header
adc = data(:, 2);  % 1 column: sample, 2 column: adc

% 对 ADC 数据做 N=8192 FFT
N = 8192;
x = adc(1:N);
X = fft(x);
mag = abs(X);
mag_dB = 20*log10(mag + 1e-10);

fs = 4e6;
df = fs / N;
freqs = (0:N-1) * df;

[peak_mag, idx] = max(mag(1:N/2));
peak_freq = freqs(idx);
fprintf('\n=== Pure FFT on ADC data ===\n');
fprintf('Peak mag: %.2f\n', peak_mag);
fprintf('Peak bin: %d\n', idx);
fprintf('Peak freq: %.4f Hz (%.4f kHz)\n', peak_freq, peak_freq/1000);

% Find bin 351 area
fprintf('\nMagnitudes around bin 350-355 (171 kHz area):\n');
for b = 340:360
    fprintf('  bin %d (%.4f kHz): %.2f\n', b, b*df/1000, mag(b+1));
end

fprintf('\nMagnitudes around bin 408-410 (200 kHz area):\n');
for b = 405:415
    fprintf('  bin %d (%.4f kHz): %.2f\n', b, b*df/1000, mag(b+1));
end

% Compare with ILA CORDIC output
fprintf('\n=== Comparison ===\n');
fprintf('Bin 351: pure FFT mag = %.2f, CORDIC mag = 24146\n', mag(352));
fprintf('Bin 408: pure FFT mag = %.2f, CORDIC mag = 631\n', mag(409));
fprintf('Bin 351/408 ratio:\n');
fprintf('  Pure FFT: %.4f\n', mag(352)/mag(409));
fprintf('  CORDIC:   %.4f\n', 24146/631);

exit
