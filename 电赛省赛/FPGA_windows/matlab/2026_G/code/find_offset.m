% find_offset.m — 假设存在固定 offset, 找出全局匹配
% 用 CORDIC mag 序列与模拟 FFT 序列做归一化相关
adc_path = 'C:\Users\24307\Desktop\FPGA_windows\adc_timeseries.csv';
data = csvread(adc_path, 1);
adc = data(:, 2);

N = 8192;
fs = 4e6;
df = fs / N;
n_idx = (0:N-1)';
w = 0.5 * (1 - cos(2*pi*n_idx/N));
x_w = round(adc) .* w;
X = fft(x_w);
mag_sim = abs(X(1:N/2));

% 读 CORDIC mag per bin
fid = fopen('C:\Users\24307\Desktop\FPGA_windows\Vivado\result\iladata.csv','r');
fgetl(fid); fgetl(fid);
bin_list = []; mag_list = [];
while true
    ln = fgetl(fid);
    if ~ischar(ln), break; end
    if isempty(ln), continue; end
    parts = strsplit(strtrim(ln), ',');
    if length(parts) < 7, continue; end
    m = str2double(parts{4});
    b = str2double(parts{5});
    v = hex2dec(parts{6});
    if isnan(m) || isnan(b) || v == 0 || m == 0, continue; end
    bin_list(end+1) = b;
    mag_list(end+1) = m;
end
fclose(fid);

% Take max per bin
nb = unique(bin_list);
mmax = zeros(size(nb));
for j = 1:length(nb)
    mask = (bin_list == nb(j));
    mmax(j) = max(mag_list(mask));
end

% Normalize both
mag_sim_n = mag_sim / max(mag_sim);
mmax_n = mmax / max(mmax);

% Try offsets
fprintf('Trying bin offset (shifting CORDIC bins):\n');
best_score = -inf;
best_off = 0;
for off = -100:100
    j_cordic = find((nb + off) >= 0 & (nb + off) < N/2);
    if isempty(j_cordic), continue; end
    cordic_bins = nb(j_cordic) + off;
    cordic_mags = mmax_n(j_cordic);
    sim_vals = mag_sim_n(cordic_bins + 1);
    score = sum(sim_vals .* cordic_mags);
    if score > best_score
        best_score = score;
        best_off = off;
    end
end
fprintf('Best offset: %d bins (score=%.4f)\n', best_off, best_score);

% Apply best offset and compare top bins
fprintf('\nAfter offset %d, top bins in CORDIC vs Simulation:\n', best_off);
% Find top 10 bins in CORDIC
[~, top_idx] = sort(mmax, 'descend');
for k = 1:10
    j = top_idx(k);
    bin = nb(j);
    new_bin = bin + best_off;
    if new_bin >= 0 && new_bin < N/2
        fprintf('  CORDIC bin %d -> sim bin %d: mag=%d, sim_mag=%.0f\n', ...
            bin, new_bin, mmax(j), mag_sim(new_bin+1));
    else
        fprintf('  CORDIC bin %d -> out of range\n', bin);
    end
end

exit
