addpath('C:\Users\24307\Desktop\FPGA_windows\matlab\exercise1\code');
data = load('C:\Users\24307\Desktop\FPGA_windows\Vivado\result\exercise1\chb_samples.csv');
fprintf('Total samples: %d\n', length(data));
n_total = length(data);
s1 = data(1:min(1024, n_total));
s1 = s1 - mean(s1);
n = length(s1);
fprintf('Scenario 1 samples: %d\n', n);
Fs = 12.5e6;
Y = abs(fft(s1));
f = (0:n-1)*Fs/n/1e6;
[~, pk_idx] = max(Y(1:floor(n/2)));
fprintf('Scenario 1: Peak at %.4f MHz (bin %d, mag %.1f)\n', f(pk_idx), pk_idx, Y(pk_idx));

% Top 10 peaks
[Y_sorted, idx] = sort(Y(1:floor(n/2)), 'descend');
fprintf('Top 10 peaks: ');
for k=1:10
    fprintf('%.4fMHz(%.0f) ', f(idx(k)), Y_sorted(k));
end
fprintf('\n');
exit(0);
