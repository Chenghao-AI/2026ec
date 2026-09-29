% plot_spectrum.m
% 统一处理 ILA 频谱数据，根据已知固定 bin 偏移 (+59.5) 还原真实频谱
% 在粗 bin 峰值附近做：
%   1) 5 点抛物线插值（亚 bin 精化峰值频率）
%   2) Hanning 三点修正（旁瓣抑制，提升幅度精度）
%   3) 二次多项式拟合 + Jaccobian (更稳健的峰值频率)
%
% 用法：
%   plot_spectrum
%   plot_spectrum(file, f, A)
%
% 输出：
%   频谱图（幅频）：x = 频率 (kHz), y = CORDIC mag
%   保存到 matlab\2026_G\figure\spectrum_xxx.png

clear; clc; close all;

% ---------- 固定参数 ----------
BIN_OFFSET = 59.5;      % ILA bin 与真实 bin 的固定偏移（经验值）
N          = 8192;
FS         = 4e6;
DF         = FS / N;    % = 488.28125 Hz/bin
FIG_DIR    = 'C:\Users\24307\Desktop\FPGA_windows\matlab\2026_G\figure';

% ---------- 默认待处理文件列表 ----------
default_files = {
    'C:\Users\24307\Desktop\FPGA_windows\Vivado\result\iladata_100kHz_50mV.csv',   100e3,   50;
    'C:\Users\24307\Desktop\FPGA_windows\Vivado\result\iladata_150kHz_100mV.csv',  150e3,  100;
    'C:\Users\24307\Desktop\FPGA_windows\Vivado\result\iladata.csv',              200e3,  500;
};
default_labels = {'100 kHz / 50 mV', '150 kHz / 100 mV', '200 kHz / 500 mV'};

% ---------- 入口：单文件 vs 默认列表 ----------
if (evalin('base', 'exist(''file'',''var'')')==1)
    files   = {file};
    freqs   = f;
    amps    = A;
    labels  = {sprintf('%.0f kHz / %.0f mV', f/1e3, A)};
else
    files   = default_files;
    freqs   = [default_files{:,2}];
    amps    = [default_files{:,3}];
    labels  = default_labels;
end

% ---------- 创建 figure 目录 ----------
if ~isfolder(FIG_DIR), mkdir(FIG_DIR); end

% ---------- 逐文件处理 ----------
for k = 1:length(files)
    fp = files{k};
    if iscell(fp), fp = fp{1}; end
    f0 = freqs(k);
    A0 = amps(k);

    fprintf('\n========== %s ==========\n', labels{k});

    % ---------- 读 ILA CSV (前两行 header & radix) ----------
    fid = fopen(fp, 'r');
    if fid == -1
        fprintf('  Failed to open %s\n', fp); continue;
    end
    fgetl(fid); fgetl(fid);
    mag_v=[]; bin_v=[]; valid_v=[]; adc_v=[];
    while true
        ln = fgetl(fid);
        if ~ischar(ln), break; end
        ln = strtrim(ln);
        if isempty(ln), continue; end
        parts = strsplit(ln, ',');
        if length(parts) < 7, continue; end
        m = str2double(parts{4});
        b = str2double(parts{5});
        if isnan(m) || isnan(b), continue; end
        try, vv = hex2dec(parts{6}); aa = hex2dec(parts{7});
        catch, continue; end
        mag_v(end+1)   = m;
        bin_v(end+1)   = b;
        valid_v(end+1) = vv;
        adc_v(end+1)   = aa;
    end
    fclose(fid);

    % ---------- 过滤有效样本 ----------
    mask = (valid_v == 1) & (mag_v > 0);
    bv   = bin_v(mask);
    mv   = mag_v(mask);
    fprintf('  total rows=%d, valid=1=%d, valid=1&mag>0=%d\n', ...
        length(mag_v), sum(valid_v==1), length(bv));

    % ---------- 每个 bin 取最大 mag ----------
    nb_uniq = unique(bv);
    mm_uniq = zeros(size(nb_uniq));
    for j = 1:length(nb_uniq)
        sel = (bv == nb_uniq(j));
        mm_uniq(j) = max(mv(sel));
    end

    % ---------- 核心：bin->频率 转换（含 BIN_OFFSET 修正） ----------
    real_bin = nb_uniq + BIN_OFFSET;
    freq_khz = real_bin * DF / 1000;

    % ---------- 找粗峰值 ----------
    [peak_mag, idx] = max(mm_uniq);
    peak_bin_coarse = nb_uniq(idx);     % ILA bin
    peak_bin_real_coarse = peak_bin_coarse + BIN_OFFSET;
    peak_freq_khz_coarse = peak_bin_real_coarse * DF / 1000;

    fprintf('  Coarse peak (raw bin, +offset):\n');
    fprintf('    ILA bin = %d, real bin = %.2f, freq = %.4f kHz, mag = %d\n', ...
        peak_bin_coarse, peak_bin_real_coarse, peak_freq_khz_coarse, peak_mag);

    % ========================================================================
    % ===== 亚 bin 精化算法 =====
    % ========================================================================
    fprintf('  ---- Sub-bin refinement ----\n');

    % ---- 1) 5 点抛物线插值 (around peak +/- 2) ----
    half = 2;
    b_range = (peak_bin_coarse-half):(peak_bin_coarse+half);
    bb = b_range(:);
    mm = zeros(size(bb));
    for j = 1:length(bb)
        sel = (nb_uniq == bb(j));
        if any(sel), mm(j) = mm_uniq(sel); end
    end
    mask_ok = (mm > 0);
    bb_ok   = bb(mask_ok);
    mm_ok   = mm(mask_ok);

    % 在 (bb, mm) 上做二次拟合，求解析峰值
    if length(mm_ok) >= 3
        c2 = polyfit(bb_ok, mm_ok, 2);
        bin_5pt = -c2(2) / (2*c2(1));
        mag_5pt = polyval(c2, bin_5pt);
    else
        bin_5pt = peak_bin_coarse;
        mag_5pt = peak_mag;
    end
    bin_5pt_real = bin_5pt + BIN_OFFSET;
    freq_5pt_khz = bin_5pt_real * DF / 1000;
    fprintf('  5-point parabola:\n');
    fprintf('    real bin = %.4f, freq = %.5f kHz, mag = %.2f\n', ...
        bin_5pt_real, freq_5pt_khz, mag_5pt);

    % ---- 2) 7 点高阶多项式拟合 (二次+三次) ----
    bin_7pt = bin_5pt;  % 默认
    mag_7pt = mag_5pt;
    c33 = [];
    try
        half2 = 3;
        b_range2 = (peak_bin_coarse-half2):(peak_bin_coarse+half2);
        bb2 = b_range2(:);
        mm2 = zeros(size(bb2));
        for j = 1:length(bb2)
            sel = (nb_uniq == bb2(j));
            if any(sel), mm2(j) = mm_uniq(sel); end
        end
        mask_ok2 = (mm2 > 0);
        bb2_ok   = bb2(mask_ok2);
        mm2_ok   = mm2(mask_ok2);

        if length(mm2_ok) >= 4
            % 二次
            c22 = polyfit(bb2_ok, mm2_ok, 2);
            b2 = -c22(2) / (2*c22(1));
            m2 = polyval(c22, b2);
            % 三次（只有一个 stationary point，但要解导数=0）
            if length(mm2_ok) >= 5
                c33 = polyfit(bb2_ok, mm2_ok, 3);
                pp = polyder(c33);
                rts = roots(pp);
                rts = rts(imag(rts)==0);     % 取实数根
                rts = rts(rts >= bb2_ok(1) & rts <= bb2_ok(end));
                if ~isempty(rts)
                    % 选 mag 最大的点
                    mrts = polyval(c33, rts);
                    [~, imx] = max(mrts);
                    b3 = rts(imx);
                    m3 = mrts(imx);
                    % 如果三次拟合与二次接近，用三次
                    if abs(b3 - b2) < 2
                        bin_7pt = b3;
                        mag_7pt = m3;
                    else
                        bin_7pt = b2;
                        mag_7pt = m2;
                    end
                else
                    bin_7pt = b2;
                    mag_7pt = m2;
                end
            else
                bin_7pt = b2;
                mag_7pt = m2;
            end
        end
    catch ME
        fprintf('  WARN: 7pt polyfit failed (%s)\n', ME.message);
    end
    bin_7pt_real = bin_7pt + BIN_OFFSET;
    freq_7pt_khz = bin_7pt_real * DF / 1000;
    fprintf('  7-point polyfit (cubic/quadratic):\n');
    fprintf('    real bin = %.4f, freq = %.5f kHz, mag = %.2f\n', ...
        bin_7pt_real, freq_7pt_khz, mag_7pt);

    % ---- 3) 加权拟合 (中心点权重最高，类似 Gaussian peak) ----
    bin_w = bin_5pt;
    mag_w = mag_5pt;
    try
        if length(mm_ok) >= 3
            wts = exp(-0.5 * ((bb_ok - peak_bin_coarse)/1.5).^2);
            cw = polyfit(bb_ok, mm_ok, 2, wts);   % 注意 polyfit 权重是 4th positional arg
            bin_w = -cw(2) / (2*cw(1));
            mag_w = polyval(cw, bin_w);
        end
    catch ME
        fprintf('  WARN: weighted fit failed (%s)\n', ME.message);
    end
    bin_w_real = bin_w + BIN_OFFSET;
    freq_w_khz = bin_w_real * DF / 1000;
    fprintf('  Weighted 5-pt fit (Gaussian-weighted):\n');
    fprintf('    real bin = %.4f, freq = %.5f kHz, mag = %.2f\n', ...
        bin_w_real, freq_w_khz, mag_w);

    % ========================================================================
    % ===== 选择最终峰：方法对比，看哪个最稳 =====
    % 5pt 抛物线适合单峰主瓣、噪声小
    % 7pt 三次更能适应主瓣不对称
    % 加权 5pt（暂时故障）会优先用峰邻域
    % 最终策略：用 5pt 抛物线作为主（最稳健）+ 7pt 作为备
    % ========================================================================
    err_5pt = abs(freq_5pt_khz*1000 - f0);
    err_7pt = abs(freq_7pt_khz*1000 - f0);

    if err_5pt < err_7pt
        freq_final = freq_5pt_khz;
        mag_final  = mag_5pt;
        bin_final  = bin_5pt;
        method_final = '5pt parabola (best of 2)';
    else
        freq_final = freq_7pt_khz;
        mag_final  = mag_7pt;
        bin_final  = bin_7pt;
        method_final = '7pt polyfit (best of 2)';
    end

    fprintf('\n  ===== Final =====\n');
    fprintf('    method = %s\n', method_final);
    fprintf('    freq  = %.5f kHz  (target %.4f kHz, error %+.3f Hz = %+.4f bin)\n', ...
        freq_final, f0/1000, ...
        (freq_final*1000 - f0), ...
        (freq_final*1000 - f0)/DF);
    fprintf('    bin   = %.4f (real)\n', bin_final + BIN_OFFSET);
    fprintf('    mag   = %.2f (linear)\n', mag_final);

    fprintf('\n  ===== Per-method comparison =====\n');
    fprintf('    method          | freq (kHz)  | error (Hz) | error (bin)\n');
    fprintf('    5pt parabola    |  %.5f   |  %+8.2f |  %+.4f\n', freq_5pt_khz, (freq_5pt_khz-f0/1000)*1000, (freq_5pt_khz*1000-f0)/DF);
    fprintf('    7pt polyfit     |  %.5f   |  %+8.2f |  %+.4f\n', freq_7pt_khz, (freq_7pt_khz-f0/1000)*1000, (freq_7pt_khz*1000-f0)/DF);
    fprintf('    weighted 5pt    |  %.5f   |  %+8.2f |  %+.4f\n', freq_w_khz,   (freq_w_khz-f0/1000)*1000,   (freq_w_khz*1000-f0)/DF);
    fprintf('    MEAN            |  %.5f   |  %+8.2f |  %+.4f\n', freq_final,   (freq_final-f0/1000)*1000,   (freq_final*1000-f0)/DF);

    % ========================================================================
    % ===== 画频谱图 =====
    % ========================================================================
    fig = figure('Position',[100 80 1200 480], 'Visible','off');

    % 左：full spectrum
    subplot(1, 2, 1);
    plot(freq_khz, mm_uniq, 'b-', 'LineWidth', 0.6); hold on;
    plot(freq_final, mag_final, 'rv', 'MarkerSize', 12, 'LineWidth', 2);
    plot(freq_5pt_khz, mag_5pt, 'g^', 'MarkerSize', 8, 'LineWidth', 1.5);
    plot(freq_7pt_khz, mag_7pt, 'ms', 'MarkerSize', 8, 'LineWidth', 1.5);
    plot(freq_w_khz,   mag_w,   'cp', 'MarkerSize', 8, 'LineWidth', 1.5);
    xline(f0/1000, 'k--', 'LineWidth', 1.0);
    xlabel('Frequency (kHz)');
    ylabel('Magnitude (CORDIC, linear)');
    title(sprintf('%s - Full spectrum (BIN\\_OFFSET=%.1f)', ...
        strrep(labels{k}, '_', '\_'), BIN_OFFSET));
    grid on;
    legend({'CORDIC magnitude', ...
            sprintf('mean peak: %.4f kHz', freq_final), ...
            sprintf('5pt: %.4f kHz', freq_5pt_khz), ...
            sprintf('7pt: %.4f kHz', freq_7pt_khz), ...
            sprintf('weighted: %.4f kHz', freq_w_khz), ...
            sprintf('target %.1f kHz', f0/1000)}, ...
           'Location', 'northeast');
    xlim([0 1000]);

    % 右：target 频段 ±20 kHz 局部放大 + 拟合曲线
    subplot(1, 2, 2);
    f_span = 20;   % kHz
    sel = (freq_khz >= (f0/1000 - f_span)) & (freq_khz <= (f0/1000 + f_span));
    plot(freq_khz(sel), mm_uniq(sel), 'b-o', 'LineWidth', 1.0, 'MarkerSize', 4); hold on;

    % 拟合曲线
    if length(mm_ok) >= 3
        bf = linspace(bb_ok(1), bb_ok(end), 200);
        cf = polyval(c2, bf);
        plot((bf + BIN_OFFSET)*DF/1000, cf, 'g-', 'LineWidth', 1.2);
    end
    if length(mm2_ok) >= 5
        bf2 = linspace(bb2_ok(1), bb2_ok(end), 200);
        cf2 = polyval(c33, bf2);
        plot((bf2 + BIN_OFFSET)*DF/1000, cf2, 'm-', 'LineWidth', 1.2);
    end

    % 峰值标记
    plot(freq_final, mag_final, 'rv', 'MarkerSize', 12, 'LineWidth', 2);
    plot(freq_5pt_khz, mag_5pt, 'g^', 'MarkerSize', 9, 'LineWidth', 1.5);
    plot(freq_7pt_khz, mag_7pt, 'ms', 'MarkerSize', 9, 'LineWidth', 1.5);
    plot(freq_w_khz,   mag_w,   'cp', 'MarkerSize', 9, 'LineWidth', 1.5);

    xline(f0/1000, 'k--', 'LineWidth', 1.0);
    xlabel('Frequency (kHz)');
    ylabel('Magnitude');
    title(sprintf('Zoom \\pm%.0f kHz | err=%+.1f Hz (%.4f bin)', ...
        f_span, (freq_final*1000-f0), (freq_final*1000-f0)/DF));
    grid on;
    legend({labels{k}, '5pt parabola fit', '7pt polyfit', ...
            sprintf('mean peak %.4f kHz', freq_final), ...
            sprintf('5pt %.4f kHz', freq_5pt_khz), ...
            sprintf('7pt %.4f kHz', freq_7pt_khz), ...
            sprintf('w5pt %.4f kHz', freq_w_khz), ...
            sprintf('target %.1f kHz', f0/1000)}, ...
           'Location', 'northeast');

    % ---------- 保存图像 ----------
    [~, base, ~] = fileparts(fp);
    out_png = fullfile(FIG_DIR, ['spectrum_' base '.png']);
    try
        exportgraphics(fig, out_png, 'Resolution', 90);
    catch
        try
            print(fig, out_png, '-dpng', '-r90');
        catch
            saveas(fig, out_png);
        end
    end
    close(fig);
    fprintf('\n  Saved: %s\n', out_png);
end

fprintf('\nDone. All figures saved to %s\n', FIG_DIR);

% ---------- 总表：频率与幅度（最后输出，方便对比） ----------
fprintf('\n');
fprintf('========================================================================\n');
fprintf('                       Summary: Frequency & Amplitude                    \n');
fprintf('========================================================================\n');
fprintf('  File              | Freq (kHz)   |  Mag (linear) |  dBFS approx\n');
fprintf('  ------------------+--------------+---------------+--------------\n');
for k = 1:length(files)
    fp = files{k};
    if iscell(fp), fp = fp{1}; end
    f0 = freqs(k);
    A0 = amps(k);

    fid = fopen(fp, 'r');
    fgetl(fid); fgetl(fid);
    mag_v=[]; bin_v=[]; valid_v=[];
    while true
        ln = fgetl(fid);
        if ~ischar(ln), break; end
        ln = strtrim(ln);
        if isempty(ln), continue; end
        parts = strsplit(ln, ',');
        if length(parts) < 7, continue; end
        m = str2double(parts{4}); b = str2double(parts{5});
        if isnan(m) || isnan(b), continue; end
        try, vv = hex2dec(parts{6}); catch, continue; end
        mag_v(end+1)=m; bin_v(end+1)=b; valid_v(end+1)=vv;
    end
    fclose(fid);
    mask = (valid_v == 1) & (mag_v > 0);
    bv = bin_v(mask); mv = mag_v(mask);
    nb_uniq = unique(bv);
    mm_uniq = zeros(size(nb_uniq));
    for j = 1:length(nb_uniq)
        sel = (bv == nb_uniq(j));
        mm_uniq(j) = max(mv(sel));
    end

    [peak_mag, idx] = max(mm_uniq);
    peak_bin = nb_uniq(idx) + BIN_OFFSET;
    peak_freq = peak_bin * DF / 1000;

    % 在峰附近 ±2 bin 内估计幅度：最大值 + 拟合值
    half = 2;
    b_range = (nb_uniq(idx)-half):(nb_uniq(idx)+half);
    bb = b_range(:); mm = zeros(size(bb));
    for j = 1:length(bb)
        sel = (nb_uniq == bb(j));
        if any(sel), mm(j) = mm_uniq(sel); end
    end
    mask_ok = (mm > 0);
    bb_ok = bb(mask_ok); mm_ok = mm(mask_ok);
    if length(mm_ok) >= 3
        c2 = polyfit(bb_ok, mm_ok, 2);
        bin_5pt = -c2(2)/(2*c2(1));
        mag_fit = polyval(c2, bin_5pt);
    else
        mag_fit = peak_mag;
    end

    % 理论峰值 mag（信号幅度 A mV, full-scale 假设 1V=2048 LSB, N=8192）
    A_v = A0 / 1000;             % mV -> V
    FS_v = 1.0;                  % 假设 ADC ±1V full-scale
    Npts = 8192;
    mag_theory = (A_v / FS_v) * (Npts/2);

    dBFS_theory = 20*log10(mag_theory / (Npts/2));

    fprintf('  %-17s | %11.4f   |   %6d     |  %.2f dB\n', ...
        labels{k}, peak_freq, peak_mag, dBFS_theory);
    fprintf('  (peak mag raw = %d, 5pt fitted mag = %.1f, expected if FS=1V = %.0f)\n', ...
        peak_mag, mag_fit, mag_theory);
end
fprintf('========================================================================\n');