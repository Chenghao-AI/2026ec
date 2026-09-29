% quick_debug.m — 用于在不经过 analyze_fft 全流程的情况下检查解析结果
function quick_debug(csv_path)
    if nargin < 1
        csv_path = 'C:\Users\24307\Desktop\FPGA_windows\Vivado\result\2026_G\hw\ila_data_full.csv';
    end
    [mt, av] = parse_ila_csv(csv_path);
    ks = cell2mat(keys(mt));
    vs = zeros(size(ks));
    for j=1:length(ks)
        vs(j) = mt(uint32(ks(j)));
    end
    pairs = [ks' vs];
    pairs = sortrows(pairs, -2);
    fprintf('Total bins loaded: %d, ADC samples: %d\n', length(ks), length(av));
    fprintf('Top 25 bins (largest mag):\n');
    for i = 1:min(25, size(pairs,1))
        fprintf('  bin=%-6d  mag=%d\n', pairs(i,1), pairs(i,2));
    end
    fprintf('\nADC stats: min=%d max=%d P2P=%d\n', ...
        min(av), max(av), max(av)-min(av));
end
