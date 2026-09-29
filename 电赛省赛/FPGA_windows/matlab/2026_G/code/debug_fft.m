% debug_fft.m - 调试 100kHz 的 ADC FFT
addpath(genpath('C:\Users\24307\Desktop\FPGA_windows\matlab\2026_G\code'));
fp = 'C:\Users\24307\Desktop\FPGA_windows\Vivado\result\iladata_100kHz_50mV.csv';
fid = fopen(fp, 'r');
fgetl(fid); fgetl(fid);
buf_idx=[]; adc_dec=[]; valid_dec=[];
while true
    ln = fgetl(fid);
    if ~ischar(ln), break; end
    parts = strsplit(strtrim(ln), ',');
    if length(parts) < 7, continue; end
    b = str2double(parts{1});
    if isnan(b), continue; end
    try
        v = hex2dec(parts{6});
        a = hex2dec(parts{7});
    catch, continue; end
    buf_idx(end+1)=b; valid_dec(end+1)=v; adc_dec(end+1)=a;
end
fclose(fid);

mask = (valid_dec == 1) & (adc_dec >= 0);
bi = buf_idx(mask);
av = adc_dec(mask);
[~, ord] = sort(bi);
av = av(ord);
bi = bi(ord);

fprintf('Length=%d, buffer range=[%d, %d]\n', length(av), min(bi), max(bi));
fprintf('First 30 ADC samples (bipolar):\n');
av_b = av - 2048;
for k = 1:min(30, length(av))
    fprintf('  %d: ADC=%d (bip=%d)\n', k, av(k), av_b(k));
end

% FFT
N = length(av);
X = fft(double(av_b));
mag_X = abs(X) / N;
halfN = floor(N/2)+1;
mag_half = mag_X(1:halfN);
freq = (0:halfN-1)' * (4e6/N);

fprintf('\nTop 10 FFT bins (excluding DC):\n');
[~, top_idx] = sort(mag_half, 'descend');
for j = 1:10
    fprintf('  bin=%d (%.4f kHz), mag=%f\n', ...
        top_idx(j)-1, freq(top_idx(j))/1000, mag_half(top_idx(j)));
end

% 看 bin 0 (DC) 是否被偏置主导
fprintf('\nDC bin (mag_half(1)) = %f\n', mag_half(1));