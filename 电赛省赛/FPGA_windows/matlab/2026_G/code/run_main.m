% run_main.m — MATLAB 入口脚本（统一 FFT 分析）
% 自动检测最新的 ILA CSV 并调用 analyze_fft()
%
% 优先级（自上而下）:
%   1) 命令行传入 (run_main('csv_path'))
%   2) ila_data_32768.csv （如果存在，为新架构优先）
%   3) ila_data_full.csv
%   4) ila_data.csv
%   5) 任意 hw/*.csv

function run_main(csv_path)
    if nargin < 1 || isempty(csv_path)
        ROOT  = 'C:\Users\24307\Desktop\FPGA_windows';
        HW    = fullfile(ROOT, 'Vivado', 'result', '2026_G', 'hw');
        candidates = { ...
            fullfile(HW, 'ila_data_32768.csv'), ...
            fullfile(HW, 'ila_data_full.csv'), ...
            fullfile(HW, 'ila_data.csv'), ...
            fullfile(HW, '*.csv') };
        csv_path = '';
        for j = 1:length(candidates)
            c = candidates{j};
            if ~isempty(dir(c))
                d = dir(c);
                if ~isempty(d)
                    csv_path = fullfile(d(1).folder, d(1).name);
                    break;
                end
            end
        end
    end

    if isempty(csv_path) || ~exist(csv_path, 'file')
        error('No valid ILA CSV found. Place one in Vivado/result/2026_G/hw/ first.');
    end

    % 根据 CSV 文件名自动选择 FFT 点数:
    %   ila_data_32768.csv / ila_32768*  -> 32768 点 FFT
    %   ila_data_full.csv / ila_data.csv -> 8192 点 (默认)
    if ~isempty(strfind(lower(csv_path), '32768'))
        n_fft_override = 32768;
    elseif ~isempty(strfind(lower(csv_path), '16384'))
        n_fft_override = 16384;
    else
        n_fft_override = 8192;
    end
    fprintf('[run_main] CSV=%s\n  detected architecture: N_FFT=%d (Δf=%.4f Hz)\n', ...
        csv_path, n_fft_override, 4e6/n_fft_override);

    addpath(genpath('C:/Users/24307/Desktop/FPGA_windows/matlab/2026_G/code'));
    try
        R = analyze_fft(csv_path, 'n_fft', n_fft_override);
    catch e
        fprintf('ERROR: %s\n', e.message);
        disp(e.stack);
        rethrow(e);
    end

    fprintf('\n=== run_main DONE ===\n');
    fprintf('Overall: %s\n', ternary(R.overall_pass, 'PASS', 'FAIL'));
    fprintf('  f_meas = %.2f Hz (err = %.2f Hz, target = %.0f Hz)\n', ...
        R.freq_meas, R.freq_err, 200e3);
    fprintf('  Vpp    = %.2f mVpp  (err = %.2f mV,  target = %.0f mVpp)\n', ...
        R.vpp_meas, R.vpp_err, 500);
end

function s = ternary(cond, a, b)
    if cond, s = a; else, s = b; end
end
