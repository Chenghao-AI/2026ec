% analyze_correct.m — 用正确的 UNSIGNED (decimal) 解读 CSV
% 重新分析 GUI 验证过的 ILA CSV

addpath(genpath('C:/Users/24307/Desktop/FPGA_windows/matlab/2026_G/code'));
csv_path = 'C:\Users\24307\Desktop\FPGA_windows\Vivado\result\iladata.csv';

% 读取 Radix 行
fid = fopen(csv_path, 'r');
hdr = fgetl(fid);
radix = fgetl(fid);
fclose(fid);
fprintf('Headers: %s\n', hdr);
fprintf('Radix  : %s\n', radix);

% 解析 Radix 行以确定每列编码
radix_fields = strsplit(radix, ',');
for k = 1:length(radix_fields)
    fprintf('  col %d: %s\n', k, strtrim(radix_fields{k}));
end

% 根据 Radix 行 mag(4)=UNSIGNED, bin(5)=UNSIGNED, valid(6)=HEX, adc(7)=HEX
% 用正确方式解析（mag/bin 用 str2double，valid/adc 用 hex2dec）
fid = fopen(csv_path, 'r');
fgetl(fid);  % header
fgetl(fid);  % radix

mag_dec = []; bin_dec = []; valid_dec = []; adc_dec = [];
while true
    ln = fgetl(fid);
    if ~ischar(ln), break; end
    if isempty(ln), continue; end
    parts = strsplit(strtrim(ln), ',');
    if length(parts) < 7, continue; end
    
    % 4=mag (DEC), 5=bin (DEC), 6=valid (HEX), 7=adc (HEX)
    m = str2double(parts{4});
    b = str2double(parts{5});
    v = hex2dec(parts{6});
    a = hex2dec(parts{7});
    
    if isnan(m) || isnan(b), continue; end
    mag_dec(end+1) = m;
    bin_dec(end+1) = b;
    valid_dec(end+1) = v;
    adc_dec(end+1) = a;
end
fclose(fid);

fprintf('\nLoaded: %d rows\n', length(mag_dec));
fprintf('Max mag (dec): %d\n', max(mag_dec));
fprintf('Max bin (dec): %d\n', max(bin_dec));

% 过滤 valid=1 且 mag>0
mask = (valid_dec == 1) & (mag_dec > 0);
mag_v = mag_dec(mask);
bin_v = bin_dec(mask);
adc_v = adc_dec(mask);
fprintf('Valid rows: %d\n', length(mag_v));

% 求每个 bin 的 max mag
n_fft = 8192;
bin_keys = unique(bin_v);
mag_max = zeros(size(bin_keys));
for j = 1:length(bin_keys)
    mask_b = (bin_v == bin_keys(j));
    mag_max(j) = max(mag_v(mask_b));
end

% Find global peak
[peak_mag, idx] = max(mag_max);
peak_bin = bin_keys(idx);
fs = 4e6;
df = fs / n_fft;
peak_freq = peak_bin * df;
fprintf('\n=== Peak Detection ===\n');
fprintf('Peak bin: %d\n', peak_bin);
fprintf('Peak freq: %.4f kHz\n', peak_freq/1000);
fprintf('Peak mag (dec): %d\n', peak_mag);

% 5-point parabola fit on peak
half_win = 2;
b_range = (peak_bin-half_win):(peak_bin+half_win);
b_range = b_range(b_range >= 0);
m_arr = zeros(size(b_range));
for j = 1:length(b_range)
    mask_b = (bin_keys == b_range(j));
    if any(mask_b), m_arr(j) = mag_max(mask_b); else, m_arr(j) = 0; end
end
b_arr = b_range;
valid_b = (m_arr > 0);
b_arr = b_arr(valid_b);
m_arr = m_arr(valid_b);
if length(b_arr) >= 3
    coeffs = polyfit(b_arr, m_arr, 2);
    vertex_bin = -coeffs(2) / (2*coeffs(1));
    fprintf('Vertex bin (5pt fit): %.4f\n', vertex_bin);
    fprintf('Vertex freq (5pt fit): %.4f Hz\n', vertex_bin * df);
end

% Amplitude from ADC
if ~isempty(adc_v)
    adc_min = min(adc_v);
    adc_max = max(adc_v);
    adc_p2p = adc_max - adc_min;
    vpp = adc_p2p * (500/4080);
    fprintf('\n=== Amplitude ===\n');
    fprintf('ADC range: %d - %d (P2P=%d)\n', adc_min, adc_max, adc_p2p);
    fprintf('Vpp: %.2f mV\n', vpp);
end

% Plot
fig = figure('Position', [100 100 1400 600], 'Visible', 'off');
subplot(1, 2, 1);
freq_axis = bin_keys * df;
plot(freq_axis/1000, mag_max, 'b-', 'LineWidth', 0.6);
hold on;
plot(peak_freq/1000, peak_mag, 'rv', 'MarkerSize', 10);
xlabel('Frequency (kHz)'); ylabel('CORDIC |X+jY|');
title(sprintf('Full spectrum, peak at bin %d (%.2f kHz), mag=%d', ...
    peak_bin, peak_freq/1000, peak_mag));
grid on;
xlim([0, 1000]);

subplot(1, 2, 2);
mask_zoom = (freq_axis >= 150e3) & (freq_axis <= 250e3);
plot(freq_axis(mask_zoom)/1000, mag_max(mask_zoom), 'b-', 'LineWidth', 1.2);
hold on;
if peak_freq >= 150e3 && peak_freq <= 250e3
    plot(peak_freq/1000, peak_mag, 'rv', 'MarkerSize', 12);
end
xlabel('Frequency (kHz)'); ylabel('CORDIC |X+jY|');
title(sprintf('Zoom 150-250 kHz, peak at %.2f kHz', peak_freq/1000));
grid on;
xlim([150, 250]);

fig_dir = 'C:\Users\24307\Desktop\FPGA_windows\matlab\2026_G\figure';
if ~isfolder(fig_dir), mkdir(fig_dir); end
print(fig, fullfile(fig_dir, 'fft_spectrum_dec.png'), '-dpng', '-r100');
fprintf('Saved fig 1\n');

% ADC waveform
if ~isempty(adc_v)
    fig2 = figure('Position', [100 100 1400 400], 'Visible', 'off');
    N = min(2000, length(adc_v));
    plot(1:N, adc_v(1:N), 'b-', 'LineWidth', 0.6);
    xlabel('Sample'); ylabel('ADC count (offset binary)');
    title(sprintf('ADC Time-Domain (first %d samples)', N));
    grid on;
    saveas(fig2, fullfile(fig_dir, 'adc_waveform_dec.png'));
    print(fig2, fullfile(fig_dir, 'adc_waveform_dec.png'), '-dpng', '-r100');
    fprintf('Saved fig 2\n');
end

fprintf('\nSaved: %s\n', fullfile(fig_dir, 'fft_spectrum_dec.png'));
exit
