% Plot FM Signal Waveform
% Generates detailed plot of FM signal with frequency analysis

function plot_fm_signal(chb_data, time_us, freq_dev)
    figure('Position', [100, 100, 1200, 800]);
    
    % FM parameters
    F_SAMPLE = 125e6;
    F_CARRIER = 15e6;
    
    % Zero-crossing detection for frequency estimation
    zero_crossings = zeros(length(chb_data)-1, 1);
    crossings_idx = 1;
    prev_above = chb_data(1) > 8192;
    
    for i = 2:length(chb_data)
        curr_above = chb_data(i) > 8192;
        if prev_above && ~curr_above
            zero_crossings(crossings_idx) = i;
            crossings_idx = crossings_idx + 1;
        end
        prev_above = curr_above;
    end
    zero_crossings(crossings_idx:end) = [];
    
    % Calculate instantaneous frequency
    periods = diff(zero_crossings);
    periods = periods(periods > 0);
    inst_freq = F_SAMPLE ./ (2 * periods);
    
    % Time axis for frequency plot
    cross_times = time_us(zero_crossings(2:end));
    
    % Plot FM signal
    subplot(3, 1, 1);
    plot(time_us, chb_data, 'r-', 'LineWidth', 0.3);
    grid on;
    xlabel('Time (us)');
    ylabel('DAC Code');
    title('FM Signal (15 MHz carrier, 4 kHz deviation)');
    ylim([0, 16383]);
    
    % Plot instantaneous frequency
    subplot(3, 1, 2);
    plot(cross_times, inst_freq/1e6, 'r-', 'LineWidth', 0.5);
    hold on;
    yline(F_CARRIER/1e6, 'b--', 'LineWidth', 1, 'DisplayName', 'Center Freq');
    yline((F_CARRIER + freq_dev)/1e6, 'g--', 'LineWidth', 1, 'DisplayName', 'Max Dev');
    yline((F_CARRIER - freq_dev)/1e6, 'g--', 'LineWidth', 1, 'DisplayName', 'Min Dev');
    hold off;
    grid on;
    xlabel('Time (us)');
    ylabel('Frequency (MHz)');
    title('Instantaneous Frequency');
    legend('Location', 'best');
    
    % Frequency histogram
    subplot(3, 1, 3);
    histogram(inst_freq/1e3, 30, 'FaceColor', 'r', 'EdgeColor', 'black');
    hold on;
    xline(mean(inst_freq)/1e3, 'b-', 'LineWidth', 2, 'DisplayName', 'Mean');
    hold off;
    grid on;
    xlabel('Frequency Deviation (kHz)');
    ylabel('Count');
    title('FM Frequency Deviation Distribution');
    
    % Save figure
    saveas(gcf, 'C:\Users\24307\Desktop\FPGA_windows\matlab\exercise1\figure\fm_signal_plot.png');
    close all;
end
