% Plot AM Signal Waveform
% Generates detailed plot of AM signal with envelope

function plot_am_signal(cha_data, time_us, mod_depth)
    figure('Position', [100, 100, 1200, 800]);
    
    % Calculate envelope
    env_high = envelope(cha_data, length(cha_data)/20, 'peak');
    env_low = envelope(-cha_data, length(cha_data)/20, 'peak');
    
    % Plot signal with envelope
    subplot(2, 1, 1);
    hold on;
    plot(time_us, cha_data, 'b-', 'LineWidth', 0.3, 'DisplayName', 'AM Signal');
    plot(time_us, env_high, 'r-', 'LineWidth', 2, 'DisplayName', 'Upper Envelope');
    plot(time_us, -env_low, 'g-', 'LineWidth', 2, 'DisplayName', 'Lower Envelope');
    hold off;
    grid on;
    xlabel('Time (us)');
    ylabel('DAC Code (14-bit)');
    title(sprintf('AM Signal Analysis (m = %.1f)', mod_depth));
    legend('Location', 'best');
    ylim([0, 16383]);
    
    % Calculate and display modulation metrics
    V_max = max(env_high);
    V_min = max(env_low);
    m_calc = (V_max - V_min) / (V_max + V_min);
    V_pp = V_max - V_min;
    
    % Zoomed view of carrier
    subplot(2, 1, 2);
    zoom_start = round(length(time_us) * 0.4);
    zoom_end = zoom_start + round(length(time_us) * 0.1);
    zoom_idx = zoom_start:zoom_end;
    plot(time_us(zoom_idx), cha_data(zoom_idx), 'b-', 'LineWidth', 0.5);
    grid on;
    xlabel('Time (us)');
    ylabel('DAC Code');
    title('Zoomed View - 15 MHz Carrier Waveform');
    
    % Add annotation
    text(0.02, 0.95, sprintf('Calculated m = %.3f\nV_pp = %d LSB\nV_max = %d\nV_min = %d', ...
        m_calc, V_pp, V_max, V_min), ...
        'Units', 'normalized', 'VerticalAlignment', 'top');
    
    % Save figure
    saveas(gcf, 'C:\Users\24307\Desktop\FPGA_windows\matlab\exercise1\figure\am_signal_plot.png');
    close all;
end
