% debug_ila.m - 调试 ILA CSV 数据读取
csv_path = 'C:\Users\24307\Desktop\FPGA_windows\Vivado\result\2026_G\hw\ila_data_full.csv';

% 读取
fid = fopen(csv_path, 'r');
fgetl(fid); fgetl(fid);
raw = textscan(fid, '%d%d%d%s%s%s%s%s', 'Delimiter', ',');
fclose(fid);

mag_dec = hex2dec(raw{4});
bin_dec = hex2dec(raw{5});
valid_dec = hex2dec(raw{6});

fprintf('Total rows: %d\n', length(mag_dec));
fprintf('mag range: %d ~ %d\n', min(mag_dec), max(mag_dec));
fprintf('bin range: %d ~ %d\n', min(bin_dec), max(bin_dec));
fprintf('valid values: %s\n', num2str(unique(valid_dec)));

valid_mask = valid_dec == 1;
fprintf('valid=1 count: %d\n', sum(valid_mask));

mag_valid = mag_dec(valid_mask);
bin_valid = bin_dec(valid_mask);

% top 10 by mag
[~, sort_idx] = sort(mag_valid, 'descend');
fprintf('\nTop 10 by mag (valid=1):\n');
for k = 1:10
    idx = sort_idx(k);
    fprintf('  mag=%d, bin=%d\n', mag_valid(idx), bin_valid(idx));
end

% top 10 by bin
[unique_bins, ~, ic] = unique(bin_valid);
max_mags = zeros(size(unique_bins));
for k = 1:length(unique_bins)
    max_mags(k) = max(mag_valid(ic == k));
end
[~, sort_idx2] = sort(max_mags, 'descend');
fprintf('\nTop 10 bins by max_mag:\n');
for k = 1:10
    fprintf('  bin=%d, max_mag=%d\n', unique_bins(sort_idx2(k)), max_mags(sort_idx2(k)));
end
