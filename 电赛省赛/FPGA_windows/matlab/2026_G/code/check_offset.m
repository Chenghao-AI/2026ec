% check_offset.m - 用三组信号反推 BIN_OFFSET 的最佳值
addpath(genpath('C:\Users\24307\Desktop\FPGA_windows\matlab\2026_G\code'));

% 三组实测：目标频率 / ILA bin / 假设偏移
% FFT bin spacing = 4e6 / 32768 = 122.07 Hz/bin (注意 FFT 是 32768 点)
% 但 BinSelect 输出 8192 个相对 bin (BIN_LO=60..BIN_HI=8251)
% 每个相对 bin 对应 122.07 Hz
% MATLAB 用了 488.28 Hz/bin (=4MHz/8192)，所以对应 4x 相对 bin

% 三组测试信号
tests = {
    'C:\Users\24307\Desktop\FPGA_windows\Vivado\result\iladata_100kHz_50mV.csv',  100e3;
    'C:\Users\24307\Desktop\FPGA_windows\Vivado\result\iladata_150kHz_100mV.csv', 150e3;
    'C:\Users\24307\Desktop\FPGA_windows\Vivado\result\iladata.csv',             200e3;
};

% 尝试不同的偏移值
offsets_to_test = 0:1:120;
errs = zeros(length(tests), length(offsets_to_test));

for k = 1:length(tests)
    fp = tests{k,1};
    f0 = tests{k,2};

    fid = fopen(fp, 'r');
    fgetl(fid); fgetl(fid);
    mag_dec=[]; bin_dec=[]; valid_dec=[];
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
        catch, continue; end
        mag_dec(end+1)=m; bin_dec(end+1)=b; valid_dec(end+1)=v;
    end
    fclose(fid);

    mask = (valid_dec == 1) & (mag_dec > 0);
    bv = bin_dec(mask); mv = mag_dec(mask);
    nb_uniq = unique(bv);
    mm_uniq = zeros(size(nb_uniq));
    for j = 1:length(nb_uniq)
        sel = (bv == nb_uniq(j));
        mm_uniq(j) = max(mv(sel));
    end

    % 找到最大 mag 的 bin
    [peak_mag_raw, idx] = max(mm_uniq);
    peak_bin_ila = nb_uniq(idx);  % ILA bin (relative)

    for o = 1:length(offsets_to_test)
        off = offsets_to_test(o);
        real_bin = peak_bin_ila + off;   % 相对 bin 0..8191
        df = 4e6 / 8192;
        f_est = real_bin * df;
        errs(k, o) = abs(f_est - f0);
    end
    fprintf('File %d (target %.0f Hz): ILA bin=%d, raw mag=%d\n', k, f0, peak_bin_ila, peak_mag_raw);
end

% 求每个 offset 下的总误差
total_err = sum(errs, 1);
[best_err, best_idx] = min(total_err);
fprintf('\nBest total offset = %d (total error = %.2f Hz)\n', offsets_to_test(best_idx), best_err);

% 输出每个 offset 的总误差
fprintf('\n  offset |  err_100k |  err_150k |  err_200k |  total\n');
[~, sort_idx] = sort(total_err);
for j = 1:min(15, length(sort_idx))
    o = offsets_to_test(sort_idx(j));
    fprintf('   %4d  |  %7.2f  |  %7.2f  |  %7.2f  |  %.2f\n', ...
        o, errs(1, sort_idx(j)), errs(2, sort_idx(j)), errs(3, sort_idx(j)), total_err(sort_idx(j)));
end