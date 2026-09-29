% analyze_glitch.m
% 毛刺专项检查：相邻周期 |Δ| 分布 + 超阈值事件统计
% 输入：cha_samples.csv / chb_samples.csv (7 × 4096 = 28672 样本)
% 输出：figure/cha_glitch_dist.png, figure/chb_glitch_dist.png, 报告

function analyze_glitch()
    close all;
    fprintf('========================================\n');
    fprintf('毛刺专项检查 (Glitch Analysis)\n');
    fprintf('========================================\n');

    base_dir   = 'C:\Users\24307\Desktop\FPGA_windows';
    csv_dir    = fullfile(base_dir, 'Vivado\result\exercise1');
    figure_dir = fullfile(base_dir, 'matlab\exercise1\figure');
    if ~exist(figure_dir, 'dir'), mkdir(figure_dir); end

    cha_file = fullfile(csv_dir, 'cha_samples.csv');
    chb_file = fullfile(csv_dir, 'chb_samples.csv');

    for f = {cha_file, chb_file}
        if ~exist(f{1}, 'file'), error('MISSING_INPUT: %s', f{1}); end
    end

    cha = read_csv(cha_file);
    chb = read_csv(chb_file);

    THRESHOLD = 1000;   % LSB 阈值 (仿真中允许的最大毛刺)
    CHA_TARGET = 0;     % 期望 0 个超阈值事件
    CHB_TARGET = 0;

    fprintf('CHA 总样本: %d\n', length(cha));
    fprintf('CHB 总样本: %d\n', length(chb));

    cha_d = abs(diff(double(cha)));
    chb_d = abs(diff(double(chb)));

    cha_max = max(cha_d);
    chb_max = max(chb_d);
    cha_above = sum(cha_d > THRESHOLD);
    chb_above = sum(chb_d > THRESHOLD);

    fprintf('CHA max|Δ| = %.0f,  超阈值事件数 = %d\n', cha_max, cha_above);
    fprintf('CHB max|Δ| = %.0f,  超阈值事件数 = %d\n', chb_max, chb_above);

    figure('Position', [100 100 1200 400]);
    histogram(cha_d, 100, 'FaceColor', [0.2 0.4 0.8]);
    grid on;
    xlabel('|Δ| (LSB)'); ylabel('Count');
    title(sprintf('CHA |Δ| Distribution (max=%.0f, above %d = %d)', cha_max, THRESHOLD, cha_above));
    saveas(gcf, fullfile(figure_dir, 'cha_glitch_dist.png'));

    figure('Position', [100 100 1200 400]);
    histogram(chb_d, 100, 'FaceColor', [0.8 0.3 0.3]);
    grid on;
    xlabel('|Δ| (LSB)'); ylabel('Count');
    title(sprintf('CHB |Δ| Distribution (max=%.0f, above %d = %d)', chb_max, THRESHOLD, chb_above));
    saveas(gcf, fullfile(figure_dir, 'chb_glitch_dist.png'));

    % --- 退出码 ---
    if cha_above <= CHA_TARGET && chb_above <= CHB_TARGET
        fprintf('GLITCH_CHECK: PASS\n');
        assignin('base', 'ANALYZE_GLITCH_PASS', 1);
        exit(0);
    else
        fprintf('GLITCH_CHECK: FAIL\n');
        assignin('base', 'ANALYZE_GLITCH_PASS', 0);
        exit(1);
    end
end

function v = read_csv(path)
    fid = fopen(path, 'r');
    n = 0; cap = 65536; v = zeros(cap, 1);
    while true
        line = fgetl(fid);
        if ~ischar(line), break; end
        n = n + 1;
        if n > cap, v = [v; zeros(cap,1)]; cap = cap * 2; end
        v(n) = sscanf(line, '%d');
    end
    fclose(fid);
    v = v(1:n);
end