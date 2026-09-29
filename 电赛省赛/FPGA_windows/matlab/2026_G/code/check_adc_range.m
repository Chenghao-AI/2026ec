% check_adc_range.m
% 检查 iladata_*.csv 里 valid=1 的 ADC 真实值范围，反推物理 LSB 大小
% 关键：ila_probe_adc 是 signed 12-bit (-2048..+2047)

clc; clear;
files = {
    'C:\Users\24307\Desktop\FPGA_windows\Vivado\result\iladata_100kHz_50mV.csv',   100e3,   50;
    'C:\Users\24307\Desktop\FPGA_windows\Vivado\result\iladata_150kHz_100mV.csv',  150e3,  100;
    'C:\Users\24307\Desktop\FPGA_windows\Vivado\result\iladata.csv',              200e3,  500;
};
labels = {'100 kHz / 50 mV', '150 kHz / 100 mV', '200 kHz / 500 mV'};

for k = 1:length(files)
    fp = files{k,1}; f0 = files{k,2}; A0 = files{k,3};
    fprintf('\n===== %s =====\n', labels{k});
    fprintf('  Target: %.0f kHz / %.0f mV\n\n', f0/1e3, A0);

    fid = fopen(fp, 'r');
    if fid == -1, fprintf('  cannot open\n'); continue; end
    fgetl(fid); fgetl(fid);

    adc_dec = [];
    valid_dec = [];
    buf_idx = [];
    while true
        ln = fgetl(fid);
        if ~ischar(ln), break; end
        ln = strtrim(ln);
        if isempty(ln), continue; end
        parts = strsplit(ln, ',');
        if length(parts) < 7, continue; end
        buf = str2double(parts{1});
        try
            v = hex2dec(parts{6});
            a = hex2dec(parts{7});
        catch
            continue;
        end
        % signed 12-bit: >0x7FF is negative
        if a > 2047, a = a - 4096; end
        buf_idx(end+1)  = buf;
        valid_dec(end+1)= v;
        adc_dec(end+1)  = a;
    end
    fclose(fid);

    mask = (valid_dec == 1);
    fprintf('  Total rows: %d, valid=1: %d\n', length(adc_dec), sum(mask));
    av = adc_dec(mask);
    bv = buf_idx(mask);
    fprintf('  ADC signed range: min=%d, max=%d, P2P=%d LSB\n', min(av), max(av), max(av)-min(av));
    fprintf('  Peak : %d LSB\n', max(abs(av)));
    fprintf('  Buffer range: %d .. %d\n', min(bv), max(bv));

    % AD9226 ±5V 输入 → 1 LSB (signed) = 5000/2048 = 2.441 mV
    P2P_mV = (max(av) - min(av)) * (5000/2048);
    fprintf('  P2P @ 5V/2048: %.2f mV\n', P2P_mV);
    fprintf('  Peak @ 5V/2048: %.2f mV\n', max(abs(av)) * (5000/2048));
    fprintf('  Ratio (ADC Vpp / source Vpp) = %.4f\n', P2P_mV / A0);
end
