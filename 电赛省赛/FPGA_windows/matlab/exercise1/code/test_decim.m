addpath('C:\Users\24307\Desktop\FPGA_windows\matlab\exercise1\code');
data = load('C:\Users\24307\Desktop\FPGA_windows\Vivado\result\exercise1\chb_samples.csv');
s1 = data(1:4096);
s1 = s1 - mean(s1);

% Try different decimation factors
for dsf = [1 4 8 16]
    s_dec = s1(1:dsf:end);
    n = length(s_dec);
    Fs_eff = 50e6 / dsf;
    Y = abs(fft(s_dec));
    f = (0:n-1)*Fs_eff/n/1e6;
    [~, pk_idx] = max(Y(1:floor(n/2)));
    fprintf('DSF=%d: Fs=%.4f MHz, Peak at %.4f MHz (bin %d, mag %.1f)\n', dsf, Fs_eff/1e6, f(pk_idx), pk_idx, Y(pk_idx));
end
exit(0);
