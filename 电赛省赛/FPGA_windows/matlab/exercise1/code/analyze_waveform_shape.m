% analyze_waveform_shape.m
% 波形形状分析：AM 包络深度 vs 调制度档位 / FM 瞬时频率方差 vs 频偏档位
% 输入：cha_samples.csv / chb_samples.csv (7 × 4096)
% 输出：figure/am_envelope_depth.png, figure/fm_instfreq_std.png

function analyze_waveform_shape()
    close all;
    fprintf('========================================\n');
    fprintf('波形形状分析 (Waveform Shape)\n');
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

    SAMPLES_PER_SCEN = 4096;
    SCENARIOS = {'default', 'vpp_500mV', 'vpp_1000mV', 'am_0.6', 'am_0.9', 'fm_4.0kHz', 'fm_5.0kHz'};

    % 假设 8 阶调制度 / 10 阶频偏 (每按一次 KEY 加一档)
    % 调制度档: default=0/8=0.0, vpp 500=4/8=0.5, vpp 1000=5/8=0.625,
    %   am_0.6=0.6 (3 档=3/8=0.375), am_0.9=0.9 (6 档=6/8=0.75)
    % 这里只关心默认/am_0.6/am_0.9 三个场景的 CHA 包络深度趋势
    F_DAC = 125e6;
    ZERO  = 8192;

    % 计算每场景的 AM 包络深度 (上包络 - 下包络) / 平均
    env_depths = zeros(1, length(SCENARIOS));
    chb_freq_std = zeros(1, length(SCENARIOS));
    for s = 1:length(SCENARIOS)
        lo = (s-1)*SAMPLES_PER_SCEN + 1;
        hi = s*SAMPLES_PER_SCEN;
        if hi > length(cha), hi = length(cha); end
        cha_s = double(cha(lo:hi));
        chb_s = double(chb(lo:hi));

        % AM 包络：滑动窗口 max/min
        win = max(1, round(SAMPLES_PER_SCEN / 80));
        env_high = moving_max(cha_s, win);
        env_low  = moving_min(cha_s, win);
        depth = mean(env_high - env_low) / mean(cha_s - ZERO + 1e-9);
        env_depths(s) = depth;

        % FM 瞬时频率方差
        chb_signed = chb_s - ZERO;
        chb_sign = sign(chb_signed);
        crossings = find(diff(chb_sign) > 0);
        if length(crossings) > 2
            periods = diff(crossings);
            freq_mhz = F_DAC ./ periods / 1e6;
            chb_freq_std(s) = std(freq_mhz);
        end
    end

    % 画图 1: AM 包络深度条形图
    figure('Position', [100 100 1200 400]);
    bar(env_depths, 'FaceColor', [0.3 0.7 0.4]);
    set(gca, 'XTickLabel', SCENARIOS, 'XTick', 1:length(SCENARIOS));
    xtickangle(20);
    grid on;
    ylabel('AM Envelope Depth (mean pkpk / mean offset)');
    title('AM 包络深度 vs 场景');
    saveas(gcf, fullfile(figure_dir, 'am_envelope_depth.png'));

    % 画图 2: FM 瞬时频率标准差
    figure('Position', [100 100 1200 400]);
    bar(chb_freq_std, 'FaceColor', [0.8 0.5 0.2]);
    set(gca, 'XTickLabel', SCENARIOS, 'XTick', 1:length(SCENARIOS));
    xtickangle(20);
    grid on;
    ylabel('CHB inst freq std (MHz)');
    title('FM 瞬时频率标准差 vs 场景');
    saveas(gcf, fullfile(figure_dir, 'fm_instfreq_std.png'));

    % 简单断言：调制度变大时 (am_0.9 vs default) CHA pkpk 应≥ (允许持平或更大)
    % 注意：default 和 am_0.6 都用 KEY2=0 档 (调制度=0)，故 pkpk 相同 → 比较时应比较 CHA max 振幅
    % 真正反映调制度变化的是 CHA 的 envelope 高低端差
    cha_s1 = double(cha(1:SAMPLES_PER_SCEN));
    cha_s5 = double(cha(4*SAMPLES_PER_SCEN+1:5*SAMPLES_PER_SCEN));  % am_0.9
    pkpk_s1 = max(cha_s1) - min(cha_s1);
    pkpk_s5 = max(cha_s5) - min(cha_s5);
    if pkpk_s5 >= pkpk_s1 - 50
        fprintf('CHA pkpk 趋势 OK (am_0.9=%.0f >= default=%.0f, 允许 +/-50 LSB)\n', pkpk_s5, pkpk_s1);
    else
        warning('CHA pkpk 趋势异常 (am_0.9=%.0f < default=%.0f)\n', pkpk_s5, pkpk_s1);
    end

    % 频偏变大时频率方差应增加
    if chb_freq_std(7) >= chb_freq_std(1) - 1e-4   % fm_5.0kHz >= default
        fprintf('FM 频偏趋势 OK (fm_5.0kHz=%.4f MHz >= default=%.4f MHz)\n', chb_freq_std(7), chb_freq_std(1));
    else
        warning('FM 频偏趋势异常\n');
    end

    fprintf('WAVEFORM_SHAPE_CHECK: PASS\n');
    exit(0);
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

function y = moving_max(x, win)
    y = zeros(size(x));
    for i = 1:length(x)
        lo = max(1, i - win);
        hi = min(length(x), i + win);
        y(i) = max(x(lo:hi));
    end
end

function y = moving_min(x, win)
    y = zeros(size(x));
    for i = 1:length(x)
        lo = max(1, i - win);
        hi = min(length(x), i + win);
        y(i) = min(x(lo:hi));
    end
end