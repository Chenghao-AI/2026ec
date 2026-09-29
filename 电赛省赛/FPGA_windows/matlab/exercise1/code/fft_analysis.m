% FFT Spectrum Analysis
% Performs frequency domain analysis of AM and FM signals

function fft_analysis(cha_data, chb_data, time_us)
    F_SAMPLE = 125e6;
    F_CARRIER = 15e6;
    
    % Calculate frequency resolution
    N = length(cha_data);
    dt = (time_us(end) - time_us(1)) * 1e-6 / N;
    df = 1 / (N * dt);
    f_axis = (0:N-1) * df;
    f_axis_mhz = f_axis / 1e6;
    
    % FFT of CHA (AM signal)
    cha_fft = fft(cha_data - mean(cha_data));
    cha_fft_mag = abs(cha_fft / N);
    cha_fft_single = cha_fft_mag(1:floor(N/2)+1);
    cha_fft_single(2:end-1) = 2 * cha_fft_single(2:end-1);
    
    % FFT of CHB (FM signal)
    chb_fft = fft(chb_data - mean(chb_data));
    chb_fft_mag = abs(chb_fft / N);
    chb_fft_single = chb_fft_mag(1:floor(N/2)+1);
    chb_fft_single(2:end-1) = 2 * chb_fft_single(2:end-1);
    
    % Plot FFT results
    figure('Position', [100, 100, 1200, 800]);
    
    % CHA Spectrum
    subplot(2, 1, 1);
    plot(f_axis_mhz, 20*log10(cha_fft_single + 1e-10), 'b-', 'LineWidth', 1);
    grid on;
    xlabel('Frequency (MHz)');
    ylabel('Magnitude (dB)');
    title('CHA Spectrum - AM Signal');
    xlim([14.9, 15.1]);
    ylim([-60, 0]);
    
    % Mark carrier and sidebands
    hold on;
    [~, carrier_idx] = max(cha_fft_single(f_axis_mhz > 14.9 & f_axis_mhz < 15.1));
    carrier_freq = f_axis_mhz(14.9e6/df + carrier_idx);
    plot(carrier_freq, 20*log10(cha_fft_single(round(14.9e6/df + carrier_idx))), 'ro', 'MarkerSize', 10);
    hold off;
    
    % CHB Spectrum
    subplot(2, 1, 2);
    plot(f_axis_mhz, 20*log10(chb_fft_single + 1e-10), 'r-', 'LineWidth', 1);
    grid on;
    xlabel('Frequency (MHz)');
    ylabel('Magnitude (dB)');
    title('CHB Spectrum - FM Signal');
    xlim([14.9, 15.1]);
    ylim([-60, 0]);
    
    % Mark carrier
    hold on;
    [~, chb_carrier_idx] = max(chb_fft_single(f_axis_mhz > 14.9 & f_axis_mhz < 15.1));
    plot(f_axis_mhz(14.9e6/df + chb_carrier_idx), ...
         20*log10(chb_fft_single(round(14.9e6/df + chb_carrier_idx))), ...
         'ko', 'MarkerSize', 10);
    hold off;
    
    % Save figure
    saveas(gcf, 'C:\Users\24307\Desktop\FPGA_windows\matlab\exercise1\figure\fft_analysis.png');
    close all;
    
    % Print analysis results
    fprintf('\nSpectrum Analysis Results:\n');
    fprintf('  CHA Carrier Power: %.2f dB\n', ...
        20*log10(cha_fft_single(round(15e6/df))));
    fprintf('  CHA Lower Sideband: %.2f dB\n', ...
        20*log10(cha_fft_single(round(14.99e6/df))));
    fprintf('  CHA Upper Sideband: %.2f dB\n', ...
        20*log10(cha_fft_single(round(15.01e6/df))));
end
