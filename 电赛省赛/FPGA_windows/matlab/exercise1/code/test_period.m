addpath('C:\Users\24307\Desktop\FPGA_windows\matlab\exercise1\code');
data = load('C:\Users\24307\Desktop\FPGA_windows\Vivado\result\exercise1\chb_samples.csv');
s1 = data(1:4096);
s1 = s1 - mean(s1);
n = length(s1);
fprintf('First 20 samples:\n');
for k=1:20
    fprintf('  s1(%d) = %d\n', k, s1(k));
end

% Check period
% Find positive zero crossings
zero_crossings = [];
for k=2:n
    if s1(k-1) < 0 && s1(k) >= 0
        zero_crossings(end+1) = k;
    end
end
fprintf('\nZero crossings: first 20 = ');
fprintf('%d ', zero_crossings(1:min(20,end)));
fprintf('\n');
if length(zero_crossings) > 1
    periods = diff(zero_crossings);
    fprintf('Periods: first 20 = ');
    fprintf('%d ', periods(1:min(20,end)));
    fprintf('\nMean period: %.2f samples\n', mean(periods));
    fprintf('At 12.5 MHz Fs: freq = %.4f MHz\n', 12.5/mean(periods));
    fprintf('At 6.25 MHz Fs: freq = %.4f MHz\n', 6.25/mean(periods));
end
exit(0);
