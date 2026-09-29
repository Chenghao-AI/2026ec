% combined_analysis.m
% Combine all three datasets, overlay, and compute offset

files = {
    'C:\Users\24307\Desktop\FPGA_windows\Vivado\result\iladata_100kHz_50mV.csv', 100e3;
    'C:\Users\24307\Desktop\FPGA_windows\Vivado\result\iladata_150kHz_100mV.csv', 150e3;
    'C:\Users\24307\Desktop\FPGA_windows\Vivado\result\iladata.csv',            200e3;
};
labels = {'100 kHz / 50 mV', '150 kHz / 100 mV', '200 kHz / 500 mV'};
N = 8192; fs = 4e6; df = fs / N;

fprintf('========== Combined bin offset analysis ==========\n');
fprintf('%-20s %-12s %-12s %-12s %-12s\n', 'test', 'target_bin', 'ila_peak_bin', 'delta', 'mag');
for k = 1:length(files)
    fp = files{k, 1};
    f = files{k, 2};
    tgt_bin = round(f / df);
    fid = fopen(fp, 'r');
    fgetl(fid); fgetl(fid);
    mag_v = []; bin_v = []; valid_v = [];
    while true
        ln = fgetl(fid);
        if ~ischar(ln), break; end
        ln = strtrim(ln);
        if isempty(ln), continue; end
        p = strsplit(ln, ',');
        if length(p) < 7, continue; end
        m = str2double(p{4});
        b = str2double(p{5});
        if isnan(m) || isnan(b), continue; end
        try, v = hex2dec(p{6});
        catch, continue; end
        mag_v(end+1) = m;
        bin_v(end+1) = b;
        valid_v(end+1) = v;
    end
    fclose(fid);

    mask = (valid_v==1) & (mag_v>0);
    bv = bin_v(mask);
    mv = mag_v(mask);
    nb = unique(bv);
    mm = zeros(size(nb));
    for j = 1:length(nb)
        sel = (bv == nb(j));
        mm(j) = max(mv(sel));
    end
    [pm, idx] = max(mm);
    pb = nb(idx);
    delta = pb - tgt_bin;
    fprintf('%-20s %-12d %-12d %-12d %-12d\n', labels{k}, tgt_bin, pb, delta, pm);
end

% ---- Generate overlay of all three CORDIC spectra vs expected frequency ----
fig = figure('Position', [50 50 1600 1000], 'Visible', 'off');
for k = 1:length(files)
    fp = files{k, 1};
    f = files{k, 2};
    tgt_bin = round(f / df);
    fid = fopen(fp, 'r');
    fgetl(fid); fgetl(fid);
    mag_v = []; bin_v = []; valid_v = []; adc_v = [];
    while true
        ln = fgetl(fid);
        if ~ischar(ln), break; end
        ln = strtrim(ln);
        if isempty(ln), continue; end
        p = strsplit(ln, ',');
        if length(p) < 7, continue; end
        m = str2double(p{4});
        b = str2double(p{5});
        if isnan(m) || isnan(b), continue; end
        try, v = hex2dec(p{6}); a = hex2dec(p{7});
        catch, continue; end
        mag_v(end+1) = m;
        bin_v(end+1) = b;
        valid_v(end+1) = v;
        adc_v(end+1) = a;
    end
    fclose(fid);

    mask = (valid_v==1) & (mag_v>0);
    bv = bin_v(mask);
    mv = mag_v(mask);
    nb = unique(bv);
    mm = zeros(size(nb));
    for j = 1:length(nb)
        sel = (bv == nb(j));
        mm(j) = max(mv(sel));
    end

    % FFT of ADC (sim)
    adc_signed = double(adc_v) - 2048;
    X = fft(adc_signed(1:N) .* (0.5*(1 - cos(2*pi*(0:N-1)'/N))));
    mag_sim = abs(X(1:N/2));

    subplot(3, 2, 2*k-1);
    plot(nb*df/1000, mm/mm.max(), 'b-', 'LineWidth', 0.7); hold on;
    plot([f/1000 f/1000], [0 1], 'r--', 'LineWidth', 1.2);
    [pm, pi] = max(mm);
    plot(nb(pi)*df/1000, pm/mm.max(), 'go', 'MarkerSize', 10, 'LineWidth', 1.5);
    xlabel('freq (kHz)'); ylabel('cordic mag (norm)');
    title(sprintf('ILA: %s', labels{k}));
    grid on; xlim([0 500]);
    subplot(3, 2, 2*k);

    plot(nb*df/1000, mm/mm.max(), 'b-', 'LineWidth', 0.7); hold on;
    plot((0:N/2-1)*df/1000, mag_sim/mag_sim.max(), 'r-', 'LineWidth', 0.7);
    plot([f/1000 f/1000], [0 1], 'g--', 'LineWidth', 1.2);
    xlabel('freq (kHz)'); ylabel('mag (norm)');
    title(sprintf('Overlay (blue=ILA, red=sim FFT) %s', labels{k}));
    grid on; xlim([0 500]); legend({'ILA','sim FFT'}, 'Location','northeast');
end

fig_dir = 'C:\Users\24307\Desktop\FPGA_windows\matlab\2026_G\figure';
try
    print(fig, fullfile(fig_dir, 'combined_spectra.png'), '-dpng', '-r100');
    fprintf('Saved: combined_spectra.png\n');
catch e
    fprintf('print failed: %s\n', e.message);
    saveas(fig, fullfile(fig_dir, 'combined_spectra.fig'));
end

exit
