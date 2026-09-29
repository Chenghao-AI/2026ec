% Measure Modulation Parameters
% Calculates AM modulation depth and FM frequency deviation

function [m_am, delta_f] = measure_modulation(cha_data, chb_data, time_us)
    % Parameters
    F_SAMPLE = 125e6;
    F_CARRIER = 15e6;
    
    % AM Modulation Depth Measurement
    env_high = envelope(cha_data, length(cha_data)/20, 'peak');
    env_low = envelope(-cha_data, length(cha_data)/20, 'peak');
    
    V_max = max(env_high);
    V_min = max(env_low);
    m_am = (V_max - V_min) / (V_max + V_min);
    
    fprintf('AM Modulation Analysis:\n');
    fprintf('  V_max = %d LSB (%.3f V)\n', V_max, V_max / 16384 * 3.0);
    fprintf('  V_min = %d LSB (%.3f V)\n', V_min, V_min / 16384 * 3.0);
    fprintf('  Modulation Depth m = %.3f (%.1f%%)\n', m_am, m_am * 100);
    
    % FM Frequency Deviation Measurement
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
    
    periods = diff(zero_crossings);
    periods = periods(periods > 0);
    inst_freq = F_SAMPLE ./ (2 * periods);
    
    delta_f_mean = mean(inst_freq) - F_CARRIER;
    delta_f_max = max(inst_freq) - F_CARRIER;
    delta_f_min = min(inst_freq) - F_CARRIER;
    
    fprintf('\nFM Frequency Deviation Analysis:\n');
    fprintf('  Mean Frequency = %.3f MHz\n', mean(inst_freq)/1e6);
    fprintf('  Mean Deviation = %.2f kHz\n', delta_f_mean/1e3);
    fprintf('  Max Deviation = %.2f kHz\n', delta_f_max/1e3);
    fprintf('  Min Deviation = %.2f kHz\n', delta_f_min/1e3);
    
    delta_f = delta_f_mean;
    
    % Summary
    fprintf('\n========================================\n');
    fprintf('Modulation Summary:\n');
    fprintf('  AM Modulation Depth: m = %.3f\n', m_am);
    fprintf('  FM Frequency Deviation: delta_f = %.2f kHz\n', delta_f/1e3);
    fprintf('========================================\n');
end
