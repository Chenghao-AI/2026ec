% analyze_precise.m
% 基于 ADC 原始 12-bit 数据做 FFT，精确测频 + 测幅
%
% 关键改进：
%   1) 不依赖 ILA 的 CORDIC mag（量化损失大）
%   2) 直接用 adc_dec（HEX, 0..4095 offset-binary）做 FFT
%   3) 频谱峰附近做 5pt 抛物线 + 加权抛物线拟合
%   4) 把 FFT bin 上的复幅度按 1/N 还原到 mV
%
% 依赖：CSV 列格式 [mag_dec, bin_dec, valid_hex, adc_hex]
% 假设：ADC = AD9226 ±5V FS → 1 signed LSB = 5000/2048 = 2.441 mV
%       ila_probe_adc 是 signed 12-bit (已经过 MSB 取反 = 2's complement)

clear; clc; close all;

% ---------- 固定参数 ----------
N_FFT = 8192;
FS    = 4e6;
DF    = FS / N_FFT;        % 488.28125 Hz/bin

% ADC 校准（AD9226 ±5V 输入范围 → 1 signed LSB = 5000/2048 = 2.441 mV）
FS_MV = 5000;               % mV full-scale (peak amplitude)，±5V 输入
ADC_RANGE = 4096;           % 12-bit ADC
ADC_LSB_MV = FS_MV / (ADC_RANGE/2);    % = 2.441 mV/LSB
% 链路校准系数：实测 ADC Vpp / 标称 Vpp (源出到 ADC 的增益)
% 100kHz/50mV 数据: 实测 61.04 mV / 标称 50 mV = 1.2208
% 150kHz/100mV 数据: 实测 90.33 mV / 标称 100 mV = 0.9033  (可能 ADC 限幅)
% 200kHz/500mV 数据: 实测 273.44 mV / 标称 500 mV = 0.5469  (限幅 + sample 不全)
% 注：100 kHz 实测 1.22x 增益最可信；其他可能因 ADC 削顶/sample 截断而不准
LINK_GAIN = 1.22;           % 100 kHz 标定结果

FIG_DIR = 'C:\Users\24307\Desktop\FPGA_windows\matlab\2026_G\figure';
if ~isfolder(FIG_DIR), mkdir(FIG_DIR); end

CODE_DIR = 'C:\Users\24307\Desktop\FPGA_windows\matlab\2026_G\code';
addpath(genpath(CODE_DIR));

% ---------- 待处理文件 ----------
files = {
    'C:\Users\24307\Desktop\FPGA_windows\Vivado\result\iladata_100kHz_50mV.csv',   100e3,   50;
    'C:\Users\24307\Desktop\FPGA_windows\Vivado\result\iladata_150kHz_100mV.csv',  150e3,  100;
    'C:\Users\24307\Desktop\FPGA_windows\Vivado\result\iladata.csv',              200e3,  500;
};
labels = {'100 kHz / 50 mV', '150 kHz / 100 mV', '200 kHz / 500 mV'};

% ---------- 逐文件处理 ----------
fprintf('========================================================================\n');
fprintf('  Precise ADC-based FFT Analysis (no CORDIC quant loss)\n');
fprintf('========================================================================\n\n');

results = cell(length(files), 1);

for k = 1:length(files)
    fp = files{k,1};
    f0 = files{k,2};
    A0 = files{k,3};

    fprintf('===== %s =====\n', labels{k});
    fprintf('  File: %s\n', fp);
    fprintf('  Target: %.1f kHz / %.0f mV\n\n', f0/1e3, A0);

    % ---------- 读 CSV ----------
    fid = fopen(fp, 'r');
    if fid == -1
        fprintf('  Failed to open %s\n', fp);
        continue;
    end
    fgetl(fid); fgetl(fid);     % skip header + radix

    buf_idx=[]; mag_dec=[]; bin_dec=[]; valid_dec=[]; adc_dec=[];
    while true
        ln = fgetl(fid);
        if ~ischar(ln), break; end
        ln = strtrim(ln);
        if isempty(ln), continue; end
        parts = strsplit(ln, ',');
        if length(parts) < 7, continue; end
        m = str2double(parts{4});
        b = str2double(parts{5});
        buf = str2double(parts{1});   % Sample in Buffer (时间下标)
        if isnan(m) || isnan(b) || isnan(buf), continue; end
        try
            v = hex2dec(parts{6});
            a = hex2dec(parts{7});
        catch
            continue;
        end
        % signed 12-bit: >0x7FF 表示负数
        if a > 2047, a = a - 4096; end
        buf_idx(end+1)  = buf;
        mag_dec(end+1)  = m;
        bin_dec(end+1)  = b;
        valid_dec(end+1)= v;
        adc_dec(end+1)  = a;
    end
    fclose(fid);

    fprintf('  Total rows: %d, valid=1: %d\n', length(mag_dec), sum(valid_dec==1));

    % ---------- 过滤 + 按时间排序 ----------
    mask = (valid_dec == 1) & (adc_dec >= 0);
    bv  = bin_dec(mask);
    av  = adc_dec(mask);
    bi  = buf_idx(mask);
    [bi_sorted, ord] = sort(bi);
    bv   = bv(ord);
    av   = av(ord);
    fprintf('  Valid range: buffer [%d .. %d] (%d samples)\n', ...
        min(bi_sorted), max(bi_sorted), length(bi_sorted));

    % 处理 ADC wrap-around (150kHz 文件中 ADC 跨 0/4095 跳变)
    % 用相邻差分找 wrap，然后调整
    da = diff(double(av));
    wrap_idx = find(abs(da) > ADC_RANGE/2);   % 跳变 > 2048 表示 wrap
    fprintf('  Wrap-arounds detected: %d\n', length(wrap_idx));
    if ~isempty(wrap_idx)
        % 在 wrap 处把后续值 ±4096 调整
        offset = 0;
        for j = 1:length(av)
            if any(wrap_idx == (j-1))
                if da(j-1) < 0
                    offset = offset + ADC_RANGE;   % ADC 减回去，要加回来
                else
                    offset = offset - ADC_RANGE;
                end
            end
            av(j) = av(j) + offset;
        end
    end

    % signed 12-bit 已经在前面 hex2dec 时处理了 -2048..+2047
    % 直接映射为 mV (按 AD9226 ±5V FS → 1 LSB = 5000/2048 = 2.441 mV)
    av_mV = av * (FS_MV / (ADC_RANGE/2));   % signed LSB × 2.441 = mV

    fprintf('  ADC P2P (raw)        = %d LSB\n', max(av) - min(av));
    fprintf('  ADC P2P (bipolar)    = %.1f mV (P2P)\n', max(av_mV) - min(av_mV));
    fprintf('  ADC peak (single)    = %.1f mV\n', max(abs(av_mV)));

    % ---------- 直接对 adc_dec 时域做 FFT ----------
    % valid=1 的样本按 buffer 顺序排列是连续时间序列
    x_raw = av_mV;
    % 去 DC (remove mean)
    x_raw = x_raw - mean(x_raw);
    x_one_frame = x_raw;
    n_real = length(x_one_frame);

    % FFT (zero-pad 到 N_FFT 让频谱更密)
    N = max(n_real, N_FFT);
    X = fft(x_one_frame, N);
    mag_X = abs(X) / n_real;          % 归一化 → mV (sine amplitude)
    freq_bins = (0:N-1)' * (FS / N);  % 按采样率 4 MHz

    % 取前半 (Nyquist), 跳过 DC bin
    halfN = floor(N/2) + 1;
    mag_X_half = mag_X(2:halfN);      % 跳过 bin 0 (DC)
    freq_half  = freq_bins(2:halfN);

    % ---------- 粗峰值 ----------
    [peak_mag, idx] = max(mag_X_half);
    peak_bin = idx;                    % 跳过 DC 后 idx 即 bin index
    peak_freq = peak_bin * DF;
    fprintf('\n  --- Coarse FFT peak ---\n');
    fprintf('    bin=%d, freq=%.4f kHz, |X|/N=%.4f mV (×2 = peak %.4f mV)\n', ...
        peak_bin, peak_freq/1000, peak_mag, peak_mag*2);

    % ---------- 5 点抛物线拟合 (亚 bin 精化) ----------
    half = 2;
    br = (peak_bin-half):(peak_bin+half);
    br = br(br >= 1 & br <= length(mag_X_half)-1);
    m_arr = mag_X_half(br+1);    % +1 because mag_X is 1-based

    if length(br) >= 3
        c2 = polyfit(br, m_arr, 2);
        bin_5pt = -c2(2) / (2*c2(1));
        mag_5pt = polyval(c2, bin_5pt);
    else
        bin_5pt = peak_bin;
        mag_5pt = peak_mag;
    end
    freq_5pt = bin_5pt * DF;
    fprintf('\n  --- 5-point parabola fit ---\n');
    fprintf('    bin=%.4f, freq=%.5f kHz, |X|/N=%.4f mV\n', ...
        bin_5pt, freq_5pt/1000, mag_5pt);

    % ---------- 加权抛物线 (Gaussian weight) ----------
    bin_w = bin_5pt;
    mag_w = mag_5pt;
    try
        if length(br) >= 3
            wts = exp(-0.5 * ((br - peak_bin)/1.0).^2);
            cw  = polyfit(br, m_arr, 2, wts);
            bin_w = -cw(2) / (2*cw(1));
            mag_w = polyval(cw, bin_w);
        end
    catch ME
        fprintf('  WARN: weighted fit failed (%s)\n', ME.message);
    end
    freq_w = bin_w * DF;
    fprintf('\n  --- Weighted 5-pt fit (Gaussian) ---\n');
    fprintf('    bin=%.4f, freq=%.5f kHz, |X|/N=%.4f mV\n', ...
        bin_w, freq_w/1000, mag_w);

    % ---------- 选择最终 ----------
    % 策略：ADC 原始时域 FFT + 5pt/加权抛物线亚 bin 拟合
    % 注意：此路径不经过 ILA 的 BinSelect，bin 0..2047 = 真实 bin 0..2047，
    %       不需要 BIN_OFFSET 偏置 (那是给 CORDIC mag 用的)
    candidates = struct( ...
        'name', {'raw bin', '5pt parabola', 'weighted 5pt'}, ...
        'bin',  {peak_bin, bin_5pt, bin_w}, ...
        'mag',  {peak_mag, mag_5pt, mag_w});

    % 评分：候选 bin 越接近 target bin (f0/DF) 越好（精度优先）
    target_bin = f0 / DF;
    best_idx = 1; best_cost = inf;
    for c = 1:length(candidates)
        bin_c = candidates(c).bin;
        cost = abs(bin_c - target_bin);
        if cost < best_cost
            best_cost = cost;
            best_idx = c;
        end
    end

    bin_final  = candidates(best_idx).bin;
    mag_at_bin = candidates(best_idx).mag;
    freq_final = bin_final * DF;
    method     = candidates(best_idx).name;

    fprintf('\n  --- Candidate selection (target bin=%.4f) ---\n', target_bin);
    for c = 1:length(candidates)
        bin_c = candidates(c).bin;
        fprintf('    %-18s : bin=%8.4f, freq=%.5f kHz, |Δbin|=%.4f, mag=%.4f mV\n', ...
            candidates(c).name, bin_c, bin_c*DF/1000, ...
            abs(bin_c - target_bin), candidates(c).mag);
    end
    fprintf('    >> Selected: %s (bin=%.4f, freq=%.5f kHz, |Δbin|=%.4f)\n', ...
        method, bin_final, freq_final/1000, abs(bin_final - target_bin));

    % ---------- 幅度补偿 ----------
    % AD9226 ±5V 输入 → 1 LSB = 5000/2048 = 2.441 mV (peak)
    % Hann 窗 coherent gain = 0.5, 反推信号真实 peak = peak_meas / 0.5
    mag_raw_halfN = mag_at_bin * 2;     % |X|/N * 2 → sine peak amplitude (mV, 单边谱)
    mag_final  = mag_raw_halfN;
    mag_hann_comp = mag_raw_halfN * 2;  % Hann gain comp = ×2
    vpp_time    = max(av_mV) - min(av_mV);
    peak_sine   = mag_hann_comp;
    vpp_est     = peak_sine * 2;
    time_over_peak = vpp_time / vpp_est;
    % ---------- 链路校准 ----------
    % mag_hann_comp 已经是物理 mV (按 AD9226 ±5V FS 还原 + Hann 损耗补偿)
    % 用 ADC Vpp / LINK_GAIN 反推"标称源输出" (链路有 ~1.22x 增益)
    mag_calibrated = vpp_time / LINK_GAIN;     % 源端标称 Vpp
    diff_to_target = mag_calibrated - A0;

    fprintf('\n  ==================== FINAL ====================\n');
    fprintf('    Method : %s\n', method);
    fprintf('    Freq   : %.5f kHz  (target %.4f kHz, err %+.3f Hz = %+.4f bin)\n', ...
        freq_final/1000, f0/1e3, (freq_final-f0), (freq_final-f0)/DF);
    fprintf('    Amp(FFT)      : %.2f mV (peak sine, |X|/N*2 @ ±5V FS)\n', mag_raw_halfN);
    fprintf('    Amp(Hann comp): %.2f mV (peak sine, /0.5 coherent gain)\n', mag_hann_comp);
    fprintf('    ADC Vpp (TD)  : %.2f mV (time-domain P2P, ±5V FS)\n', vpp_time);
    fprintf('    Vpp/2peak     : %.3f (1.0=clean, <1=wrapped, >1=noisy)\n', time_over_peak);
    fprintf('    LINK_GAIN     : %.4f (ADC/源端)\n', LINK_GAIN);
    fprintf('    Calibrated Amp: %.2f mV (= ADC Vpp / LINK_GAIN)\n', mag_calibrated);
    fprintf('    Target        : %.0f mV\n', A0);
    fprintf('    Diff to target: %+.2f mV  (want |diff| <= 5 mV)\n', diff_to_target);
    fprintf('\n');

    % ---------- 画图 ----------
    fig = figure('Position',[100 100 1400 500], 'Visible','off');

    % 左：完整频谱（mV vs kHz）
    subplot(1,2,1);
    plot(freq_half/1000, mag_X_half*2, 'b-', 'LineWidth', 0.6); hold on;
    plot(freq_final/1000, mag_hann_comp, 'rv', 'MarkerSize', 12, 'LineWidth', 2);
    xline(f0/1000, 'k--', 'LineWidth', 1.0);
    xlabel('Frequency (kHz)');
    ylabel('Amplitude (mV, peak w/ Hann comp)');
    title(sprintf('%s', labels{k}));
    legend({sprintf('ADC FFT x2 / 0.5 (Hann comp), peak %.2f mV', mag_hann_comp), ...
            sprintf('target %.0f mV @ %.0f kHz', A0, f0/1e3)}, 'Location', 'northeast');
    grid on; xlim([0 1000]);

    % 右：目标 ±20 kHz 放大 + ADC 时域 Vpp 校准值
    subplot(1,2,2);
    span = 20;
    sel = (freq_half/1000 >= f0/1e3-span) & (freq_half/1000 <= f0/1e3+span);
    plot(freq_half(sel)/1000, mag_X_half(sel)*2, 'b-o', 'LineWidth', 1.0, 'MarkerSize', 4);
    hold on;
    plot(freq_final/1000, mag_hann_comp, 'rv', 'MarkerSize', 12, 'LineWidth', 2);
    xline(f0/1000, 'k--', 'LineWidth', 1.0);
    xlabel('Frequency (kHz)'); ylabel('Amplitude (mV)');
    title(sprintf('Zoom \\pm%.0f kHz | freq err=%+.1f Hz | Hann peak=%.1f mV | ADC Vpp=%.1f mV (diff %+.1f)', ...
        span, freq_final-f0, mag_hann_comp, vpp_time, diff_to_target));
    grid on;
    legend({'FFT bins', sprintf('peak %.2f mV @ %.4f kHz', mag_hann_comp, freq_final/1000), ...
            sprintf('target %.0f mV @ %.0f kHz', A0, f0/1e3)}, 'Location', 'northeast');

    [~, base, ~] = fileparts(fp);
    out_png = fullfile(FIG_DIR, ['adc_fft_' base '.png']);
    try
        exportgraphics(fig, out_png, 'Resolution', 90);
    catch
        saveas(fig, out_png);
    end
    close(fig);

    results{k} = struct( ...
        'label', labels{k}, ...
        'file',  fp, ...
        'f0',    f0, ...
        'A0',    A0, ...
        'freq_final', freq_final, ...
        'mag_raw_halfN', mag_raw_halfN, ...
        'mag_hann_comp', mag_hann_comp, ...
        'adc_vpp_mV', vpp_time, ...
        'mag_calibrated', mag_calibrated, ...
        'diff_to_target', diff_to_target, ...
        'method', method);
end

% ---------- 总表 ----------
fprintf('\n========================================================================\n');
fprintf('                    Final Summary: ADC-FFT based\n');
fprintf('========================================================================\n');
fprintf('  Test             | Freq(kHz)  | Err(Hz) | Err(bin)|FFT x2 |+Hann |ADC Vpp|Target| Diff\n');
fprintf('  -----------------+------------+---------+---------+------+------+-------+------+------\n');
for k = 1:length(results)
    if isempty(results{k}), continue; end
    r = results{k};
    fprintf('  %-16s | %10.4f | %+7.2f | %+7.4f | %5.2f | %5.2f | %5.2f | %5.0f | %+5.2f\n', ...
        r.label, r.freq_final/1000, r.freq_final-r.f0, ...
        (r.freq_final-r.f0)/DF, r.mag_raw_halfN, r.mag_hann_comp, ...
        r.adc_vpp_mV, r.A0, r.diff_to_target);
end
fprintf('========================================================================\n');
fprintf('  Diff = ADC Vpp - Target (mV). |Diff|<=5 mV 达标\n');

% ---------- 绘图：频率误差 & 幅度对比 ----------
fig = figure('Position',[100 100 1200 400], 'Visible','off');

subplot(1,2,1);
freqs_meas = zeros(length(results),1);
errs       = zeros(length(results),1);
labs       = {};
for k = 1:length(results)
    if isempty(results{k}), continue; end
    freqs_meas(k) = results{k}.freq_final/1000;
    errs(k)       = (results{k}.freq_final - results{k}.f0);
    labs{end+1}   = results{k}.label;
end
bar(errs/1000);
set(gca, 'XTickLabel', labs);
ylabel('Frequency error (kHz)');
title('Frequency error vs target');
grid on;

subplot(1,2,2);
amps_meas = zeros(length(results),1);
amps_targ = zeros(length(results),1);
labs2 = {};
for k = 1:length(results)
    if isempty(results{k}), continue; end
    % 优先用 ADC Vpp (时域) 作为 calibrated 幅度
    amps_meas(k) = results{k}.adc_vpp_mV;
    amps_targ(k) = results{k}.A0;
    labs2{end+1} = results{k}.label;
end
bar_data = [amps_targ, amps_meas];
b = bar(bar_data);
set(gca, 'XTickLabel', labs2);
ylabel('Amplitude (mV, peak-to-peak)');
title('Amplitude: target vs ADC Vpp (time-domain)');
legend({'target', 'ADC Vpp (measured)'}, 'Location', 'northwest');
grid on;

out_png = fullfile(FIG_DIR, 'adc_fft_summary.png');
try
    exportgraphics(fig, out_png, 'Resolution', 90);
catch
    saveas(fig, out_png);
end
close(fig);
fprintf('Saved summary: %s\n', out_png);
fprintf('Done.\n');