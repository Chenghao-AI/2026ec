% analyze_two_signals.m
% Analyse two new ILA captures (100 kHz / 50 mV and 150 kHz / 100 mV)
% All CSVs use UNSIGNED decimal for mag/bin, HEX for valid/adc (confirmed).

% ---------- Settings ----------
fs = 4e6;
N  = 8192;
df = fs / N;
N_HALF = N / 2;

files = {
    'C:\Users\24307\Desktop\FPGA_windows\Vivado\result\iladata_100kHz_50mV.csv', ...
    'C:\Users\24307\Desktop\FPGA_windows\Vivado\result\iladata_150kHz_100mV.csv'  ...
};
labels = {'100 kHz / 50 mV', '150 kHz / 100 mV'};
targets_f = [100e3, 150e3];   % Hz
targets_a = [50,   100];     % mVpp target

fig_dir = 'C:\Users\24307\Desktop\FPGA_windows\matlab\2026_G\figure';
if ~isfolder(fig_dir), mkdir(fig_dir); end

for k = 1:length(files)
    fp = files{k};
    fprintf('\n========== %s ==========\n', labels{k});

    % Read CSV
    fid = fopen(fp, 'r');
    fgetl(fid); fgetl(fid);  % header & radix
    mag_v = []; bin_v = []; valid_v = []; adc_v = [];
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
        try
            v = hex2dec(parts{6});
            a = hex2dec(parts{7});
        catch
            continue;
        end
        mag_v(end+1)  = m;
        bin_v(end+1)  = b;
        valid_v(end+1)= v;
        adc_v(end+1)  = a;
    end
    fclose(fid);

    fprintf('  rows: %d\n', length(mag_v));
    fprintf('  valid=1 cnt: %d\n', sum(valid_v==1));
    fprintf('  Max bin: %d\n', max(bin_v));
    fprintf('  Max mag: %d\n', max(mag_v));

    % Per-bin max
    mask_v = (valid_v == 1) & (mag_v > 0);
    bv = bin_v(mask_v);
    mv = mag_v(mask_v);
    nb = unique(bv);
    mm = zeros(size(nb));
    for j = 1:length(nb)
        sel = (bv == nb(j));
        mm(j) = max(mv(sel));
    end

    % Global peak (bin with largest CORDIC mag)
    [peak_mag, idx] = max(mm);
    peak_bin = nb(idx);
    peak_freq = peak_bin * df;

    fprintf('  Peak bin (global): %d, freq=%.4f kHz, mag=%d\n', ...
        peak_bin, peak_freq/1000, peak_mag);

    % 5-point parabola fit around peak
    half = 2;
    b_range = (peak_bin-half):(peak_bin+half);
    b_range = b_range(b_range >= 0 & b_range <= 2047);
    m_arr = zeros(size(b_range));
    for j = 1:length(b_range)
        sel = (nb == b_range(j));
        if any(sel), m_arr(j) = mm(sel); else, m_arr(j) = 0; end
    end
    bb = b_range(m_arr > 0);
    mmb = m_arr(m_arr > 0);
    if length(bb) >= 3
        c = polyfit(bb, mmb, 2);
        vb = -c(2)/(2*c(1));
        vf = vb * df;
        fprintf('  5pt fit bin=%.4f freq=%.4f kHz\n', vb, vf/1000);
    end

    % ADC amplitude calibration
    adc_signed = double(adc_v) - 2048;
    adc_min = min(adc_signed);
    adc_max = max(adc_signed);
    adc_p2p = adc_max - adc_min;
    vpp_meas = adc_p2p * (500 / 4080);
    fprintf('  ADC range: %d..%d, P2P=%d, Vpp=%.2f mV\n', ...
        adc_min, adc_max, adc_p2p, vpp_meas);

    % ---- 2nd method: Compute FFT of ADC samples directly ----
    adc_q = round(double(adc_v));
    X = fft(adc_q .* (0.5*(1 - cos(2*pi*(0:N-1)'/N))));
    mag_sim = abs(X(1:N_HALF));
    [~, sim_peak_idx] = max(mag_sim);
    sim_peak_bin = sim_peak_idx - 1;
    fprintf('  SIM (FFT on raw ADC): peak bin=%d, freq=%.4f kHz, mag=%.0f\n', ...
        sim_peak_bin, sim_peak_bin*df/1000, mag_sim(sim_peak_idx));

    % ---- Cross-correlation to find bin offset between cordic and sim ----
    cordic_n = mm / max(mm);
    sim_full = mag_sim / max(mag_sim);
    best_score = -inf;
    best_off = 0;
    for off = -200:200
        mapped = nb + off;
        ok = (mapped >= 0) & (mapped < N_HALF);
        if ~any(ok), continue; end
        score = sum(cordic_n(ok) .* sim_full(mapped(ok)+1));
        if score > best_score
            best_score = score;
            best_off = off;
        end
    end
    fprintf('  Best bin offset (cordic_bin - sim_bin): %d (score=%.4f)\n', ...
        best_off, best_score);

    % If best_off != 0, print corrected top bins
    if best_off ~= 0
        fprintf('  TOP bins after correction (cordic_bin -> sim_bin):\n');
        [~, sort_i] = sort(mm, 'descend');
        for j = 1:min(8, length(sort_i))
            cb = nb(sort_i(j));
            sb = cb + best_off;
            if sb >= 0 && sb < N_HALF
                fprintf('    cordic bin %4d -> sim bin %4d (%.4f kHz), cordic mag=%5d, sim mag=%.0f\n', ...
                    cb, sb, sb*df/1000, mm(sort_i(j)), mag_sim(sb+1));
            end
        end
    end

    % ---- Plot ----
    fig = figure('Position', [100 100 1400 600], 'Visible', 'off');
    subplot(1, 2, 1);
    fa = nb * df;
    plot(fa/1000, mm, 'b-', 'LineWidth', 0.6); hold on;
    plot(peak_freq/1000, peak_mag, 'rv', 'MarkerSize', 10, 'LineWidth', 2);
    xlabel('Frequency (kHz)');
    ylabel('CORDIC |X+jY|');
    title(sprintf('%s - Full spectrum (as seen in ILA)', labels{k}));
    grid on;
    xlim([0, 1000]);

    subplot(1, 2, 2);
    % overlay (1) CORDIC as-is vs (2) CORDIC shifted by best_off
    plot(fa/1000, mm, 'b-', 'LineWidth', 0.8, 'DisplayName', 'CORDIC (ILA)'); hold on;
    if best_off ~= 0
        nb_shifted = nb + best_off;
        ok = (nb_shifted >= 0) & (nb_shifted < N_HALF);
        plot(nb_shifted(ok)*df/1000, mm(ok), 'r--', 'LineWidth', 0.8, ...
            'DisplayName', sprintf('CORDIC shifted by %d', best_off));
    end
    plot((0:N_HALF-1)*df/1000, mag_sim/max(mag_sim)*max(mm), 'g-', 'LineWidth', 0.8, ...
        'DisplayName', 'Sim FFT (raw ADC)');
    xlabel('Frequency (kHz)');
    ylabel('mag (shared scale)');
    title(sprintf('%s - CORDIC vs sim FFT (offset %d)', labels{k}, best_off));
    grid on;
    legend('Location', 'northeast');
    xlim([0, 600]);
    ylim([0, max(mm)*1.1]);

    fn = sprintf('spectrum_%dk_%dmV.png', round(targets_f(k)/1e3), round(targets_a(k)));
    print(fig, fullfile(fig_dir, fn), '-dpng', '-r100');
    close(fig);
    fprintf('  Saved figure: %s\n', fullfile(fig_dir, fn));

    % ADC waveform
    fig2 = figure('Position', [100 100 1400 400], 'Visible', 'off');
    nn = min(500, length(adc_signed));
    plot(1:nn, adc_signed(1:nn), 'b-', 'LineWidth', 0.7);
    xlabel('Sample'); ylabel('ADC signed');
    title(sprintf('%s - ADC waveform (first %d samples) Vpp=%.1f mV', ...
        labels{k}, nn, vpp_meas));
    grid on;
    fn2 = sprintf('adc_%dk_%dmV.png', round(targets_f(k)/1e3), round(targets_a(k)));
    print(fig2, fullfile(fig_dir, fn2), '-dpng', '-r100');
    close(fig2);
end

exit
