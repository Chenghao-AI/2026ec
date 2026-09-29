% peek_csv.m - 看一个 CSV 的前 100 行和 adc_dec 分布
addpath(genpath('C:\Users\24307\Desktop\FPGA_windows\matlab\2026_G\code'));
fp = 'C:\Users\24307\Desktop\FPGA_windows\Vivado\result\iladata_150kHz_100mV.csv';
fid = fopen(fp, 'r');
fgetl(fid); fgetl(fid);
mag_dec=[]; bin_dec=[]; valid_dec=[]; adc_dec=[];
while true
    ln = fgetl(fid);
    if ~ischar(ln), break; end
    parts = strsplit(strtrim(ln), ',');
    if length(parts) < 7, continue; end
    m = str2double(parts{4});
    b = str2double(parts{5});
    if isnan(m) || isnan(b), continue; end
    try
        v = hex2dec(parts{6});
        a = hex2dec(parts{7});
    catch
        continue;
    end
    mag_dec(end+1)=m; bin_dec(end+1)=b; valid_dec(end+1)=v; adc_dec(end+1)=a;
end
fclose(fid);

fprintf('Total rows=%d, valid=1: %d\n', length(mag_dec), sum(valid_dec==1));
fprintf('ADC range: min=%d (0x%s), max=%d (0x%s)\n', ...
    min(adc_dec), dec2hex(min(adc_dec)), max(adc_dec), dec2hex(max(adc_dec)));
fprintf('ADC histogram (0..4095, step 256):\n');
edges = 0:256:4096;
histc_data = histc(adc_dec, edges);
for k = 1:length(edges)-1
    fprintf('  %4d-%4d: %d\n', edges(k), edges(k+1), histc_data(k));
end

fprintf('\nFirst 50 rows (Buffer, Window, mag, bin, valid, adc):\n');
for k = 1:min(50, length(mag_dec))
    fprintf('  %5d | mag=%5d bin=%4d valid=%d adc=0x%s(%d)\n', ...
        k, mag_dec(k), bin_dec(k), valid_dec(k), ...
        dec2hex(adc_dec(k)), adc_dec(k));
end
fprintf('\nValid rows first 50:\n');
vk = find(valid_dec==1);
for j = 1:min(50, length(vk))
    k = vk(j);
    fprintf('  buf=%5d | mag=%5d bin=%4d adc=0x%s(%d)\n', ...
        k, mag_dec(k), bin_dec(k), dec2hex(adc_dec(k)), adc_dec(k));
end