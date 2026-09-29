% Save as Windows path
addpath('C:\Users\24307\Desktop\FPGA_windows\matlab\exercise1\code');
data = load('C:\Users\24307\Desktop\FPGA_windows\Vivado\result\exercise1\chb_samples.csv');
s1 = data(1:4096);
s1 = s1 - mean(s1);
n = length(s1);
Fs = 50e6;
Y = abs(fft(s1));
f = (0:n-1)*Fs/n/1e6;
[~, pk_idx] = max(Y(1:floor(n/2)));
fprintf('Scenario 1: Peak at %.4f MHz (bin %d, mag %.1f)\n', f(pk_idx), pk_idx, Y(pk_idx));
[Y_sorted, idx] = sort(Y(1:floor(n/2)), 'descend');
fprintf('Top 5 peaks: ');
for k=1:5
    fprintf('%.4fMHz(%.0f) ', f(idx(k)), Y_sorted(k));
end
fprintf('\n');
exit(0);
