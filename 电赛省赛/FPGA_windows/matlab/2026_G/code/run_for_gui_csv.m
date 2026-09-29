% run_for_gui_csv.m — 用 GUI 导出的 iladata.csv 调用 analyze_fft
% 路径: Vivado/result/iladata.csv (GUI 验证过的 CSV)

addpath(genpath('C:/Users/24307/Desktop/FPGA_windows/matlab/2026_G/code'));
csv_path = 'C:\Users\24307\Desktop\FPGA_windows\Vivado\result\iladata.csv';
fprintf('--- Analyzing GUI validated CSV ---\n');
R = analyze_fft(csv_path, 'n_fft', 8192);
fprintf('\nFinal:\n');
fprintf('  f_meas = %.4f Hz, err = %.4f Hz\n', R.freq_meas, R.freq_err);
fprintf('  Vpp    = %.4f mV, err = %.4f mV\n', R.vpp_meas, R.vpp_err);
exit
