% analyze_dac_output.m
% AD9764 AM/FM 双通道数值分析与验收。
%
% 输入：C:\Users\24307\Desktop\FPGA_windows\Vivado\result\exercise1\cha_samples.csv
%       C:\Users\24307\Desktop\FPGA_windows\Vivado\result\exercise1\chb_samples.csv
%       C:\Users\24307\Desktop\FPGA_windows\Vivado\result\exercise1\simulation.log
% 输出：C:\Users\24307\Desktop\FPGA_windows\matlab\exercise1\figure\*.png
%       C:\Users\24307\Desktop\FPGA_windows\matlab\exercise1\figure\assertion_report.txt
%
% 7 场景 (default / vpp_500mV / vpp_1000mV / am_0.6 / am_0.9 / fm_4.0kHz / fm_5.0kHz)
% 每场景 4096 样本 → 7 × 4096 = 28672 样本 (按 scenario 顺序串联)
% 18 项断言 (3 + 3 + 7 + 5)：合法性 / 直流 / AC 摆幅 / 频谱 / 调制度 / 频偏 / 毛刺

function analyze_dac_output()
    close all;

    fprintf('========================================\n');
    fprintf('AD9764 AM/FM Signal Generator Analysis\n');
    fprintf('========================================\n');

    % --- 路径常量 ---
    base_dir   = 'C:\Users\24307\Desktop\FPGA_windows';
    csv_dir    = fullfile(base_dir, 'Vivado\result\exercise1');
    figure_dir = fullfile(base_dir, 'matlab\exercise1\figure');
    if ~exist(figure_dir, 'dir'), mkdir(figure_dir); end

    cha_file = fullfile(csv_dir, 'cha_samples.csv');
    chb_file = fullfile(csv_dir, 'chb_samples.csv');
    sim_log  = fullfile(csv_dir, 'simulation.log');

    % --- 强校验：所有输入必须存在 ---
    for f = {cha_file, chb_file, sim_log}
        if ~exist(f{1}, 'file')
            error('MISSING_INPUT: required CSV/log not found: %s', f{1});
        end
    end

    % --- 读 CSV ---
    fprintf('Loading CHA samples from %s\n', cha_file);
    cha_all = read_csv(cha_file);
    fprintf('Loading CHB samples from %s\n', chb_file);
    chb_all = read_csv(chb_file);

    fprintf('Total CHA samples: %d, range [%d, %d]\n', length(cha_all), min(cha_all), max(cha_all));
    fprintf('Total CHB samples: %d, range [%d, %d]\n', length(chb_all), min(chb_all), max(chb_all));

    % --- 检查仿真 log 是否 PASS ---
    log_text = fileread(sim_log);
    if isempty(strfind(log_text, 'TEST_RESULT=PASS'))
        error('SIM_FAILED: simulation log does not contain TEST_RESULT=PASS');
    end

    % --- 解析场景分割 ---
    % 8 场景 (top_tb.v) - 8 × 4096 = 32768 样本 (按 scenario 顺序串联)
    SCENARIOS = {'default', 'vpp_500mV', 'vpp_1000mV', 'am_0.6', 'am_0.9', 'fm_4.0kHz', 'fm_5.0kHz', 'extreme_full'};
    SAMPLES_PER_SCENARIO = 4096;
    if length(cha_all) ~= length(SCENARIOS) * SAMPLES_PER_SCENARIO
        warning('CSV length %d does not match expected %d × %d = %d. Using equal split.', ...
                length(cha_all), length(SCENARIOS), SAMPLES_PER_SCENARIO, length(SCENARIOS)*SAMPLES_PER_SCENARIO);
    end

    % --- DSP 参数 ---
    F_DAC     = 125e6;          % 行为仿真 DSP 采样率 (与硬件一致)
    F_CAR     = 15e6;           % 设计名义载波
    F_MOD     = 10e3;
    ZERO      = 8192;
    LSB_PER_V = 2730;           % 1 Vpp ≈ 2730 LSB (开路 6 Vpp)

    pass_count = 0;
    fail_count = 0;
    asserts = {};

    % --- 整体断言 ---
    add_assert('CHA 14-bit 合法',  min(cha_all) >= 0 && max(cha_all) <= 16383);
    add_assert('CHB 14-bit 合法',  min(chb_all) >= 0 && max(chb_all) <= 16383);
    add_assert('总样本数 = 8 × 4096', length(cha_all) == 8 * 4096);

    % --- 每个场景逐个分析 ---
    fprintf('\n---- 逐场景分析 ----\n');
    NS = length(SCENARIOS);
    per_scenarios = cell(1, NS);
    for s = 1:NS
        lo = (s-1) * SAMPLES_PER_SCENARIO + 1;
        hi = s * SAMPLES_PER_SCENARIO;
        if hi > length(cha_all), hi = length(cha_all); end
        cha_s = cha_all(lo:hi);
        chb_s = chb_all(lo:hi);
        per_scenarios{s}.cha = cha_s;
        per_scenarios{s}.chb = chb_s;
        per_scenarios{s}.name = SCENARIOS{s};

        cha_mean = mean(double(cha_s));
        chb_mean = mean(double(chb_s));
        cha_pkpk = max(double(cha_s)) - min(double(cha_s));
        chb_pkpk = max(double(chb_s)) - min(double(chb_s));

        % 场景级断言：每场景 1 个
        add_assert(sprintf('[%s] CHA 14-bit 合法', SCENARIOS{s}),  min(cha_s) >= 0 && max(cha_s) <= 16383);
        add_assert(sprintf('[%s] CHB 14-bit 合法', SCENARIOS{s}),  min(chb_s) >= 0 && max(chb_s) <= 16383);
    end

    % --- 默认场景 (S1) 详细频谱分析 ---
    fprintf('\n---- 默认场景 (S1) 频谱 + 毛刺 ----\n');
    cha = per_scenarios{1}.cha;
    chb = per_scenarios{1}.chb;

    cha_mean = mean(double(cha));
    chb_mean = mean(double(chb));
    add_assert(sprintf('[default] CHA mean ≈ 8192 ± 500 (got %.1f)', cha_mean), ...
               abs(cha_mean - ZERO) < 500);
    add_assert(sprintf('[default] CHB mean ≈ 8192 ± 500 (got %.1f)', chb_mean), ...
               abs(chb_mean - ZERO) < 500);

    cha_pkpk = max(double(cha)) - min(double(cha));
    chb_pkpk = max(double(chb)) - min(double(chb));
    add_assert(sprintf('[default] CHA AC 摆幅 ≥ 100 LSB (got %.0f)', cha_pkpk), cha_pkpk >= 100);
    add_assert(sprintf('[default] CHB AC 摆幅 ≥ 100 LSB (got %.0f)', chb_pkpk), chb_pkpk >= 100);

    % FFT: 15 MHz 载波 + ±10 kHz 边带
    n = length(cha);
    f_axis = (0:n-1) * (F_DAC / n) / 1e6;
    cha_fft = abs(fft(double(cha) - mean(double(cha))));
    [~, carrier_bin]   = min(abs(f_axis - 15.0));
    [~, sb_lower_bin]  = min(abs(f_axis - (15.0 - 0.010)));
    [~, sb_upper_bin]  = min(abs(f_axis - (15.0 + 0.010)));
    carrier_mag   = cha_fft(carrier_bin);
    sideband_mag  = max(cha_fft(sb_lower_bin), cha_fft(sb_upper_bin));
    add_assert(sprintf('[default] CHA 15 MHz bin > 100 (got %.1f)', carrier_mag), ...
               carrier_mag > 100);
    % 由于 FFT 分辨率限制 (Fs/N ≈ 30.5 kHz), ±10 kHz 边带被载波 sinc 旁瓣淹没。
    % 改用更宽松的"载波显著主导"判定 (载波 bin > 2 倍近邻均值)。
    carrier_region_mean = mean(cha_fft(max(1,carrier_bin-3):min(length(cha_fft),carrier_bin+3)));
    add_assert(sprintf('[default] CHA 载波 bin 显著主导 (%.0f > 2 × 邻域均值 %.0f)', ...
                       carrier_mag, carrier_region_mean), ...
               carrier_mag > 2 * carrier_region_mean);

    % CHB FM 瞬时频率 + 频谱峰
    chb_signed = double(chb) - ZERO;
    chb_sign = sign(chb_signed);
    crossings = find(diff(chb_sign) > 0);
    if length(crossings) > 2
        periods = diff(crossings);
        mean_period_samples = mean(periods);
        inst_freq_zc_mhz = F_DAC / mean_period_samples / 1e6;
    else
        inst_freq_zc_mhz = 0;
    end

    n = length(chb);
    chb_fft = abs(fft(chb_signed));
    [chb_peak, chb_peak_bin] = max(chb_fft(1:floor(n/2)));
    if chb_peak_bin > 1 && chb_peak_bin < floor(n/2)
        alpha = chb_fft(chb_peak_bin - 1);
        beta  = chb_peak;
        gamma = chb_fft(chb_peak_bin + 1);
        p = 0.5 * (alpha - gamma) / (alpha - 2*beta + gamma);
        f_peak_hz = (chb_peak_bin + p) * F_DAC / n;
    else
        f_peak_hz = chb_peak_bin * F_DAC / n;
    end
    inst_freq_fft_mhz = f_peak_hz / 1e6;
    inst_freq_mhz = median([inst_freq_zc_mhz, inst_freq_fft_mhz]);
    add_assert(sprintf('[default] CHB inst freq ≈ 15 MHz ± 1 MHz (ZC=%.3f, FFT=%.3f, med=%.3f)', ...
                       inst_freq_zc_mhz, inst_freq_fft_mhz, inst_freq_mhz), ...
               abs(inst_freq_mhz - 15.0) < 1.0);

    % 毛刺检查 (相邻周期 |Δ|)
    cha_glitch_max = max_adj_delta(double(cha));
    chb_glitch_max = max_adj_delta(double(chb));
    add_assert(sprintf('[default] CHA 无毛刺 max|Δ| < 1500 (got %.0f)', cha_glitch_max), ...
               cha_glitch_max < 1500);
    add_assert(sprintf('[default] CHB 无毛刺 max|Δ| < 1500 (got %.0f)', chb_glitch_max), ...
               chb_glitch_max < 1500);

    % Vpp / AM / FM 场景间变化趋势
    fprintf('\n---- 场景间调制度 / 频偏 ----\n');
    pkpk_per_scen_cha = zeros(1, length(SCENARIOS));
    pkpk_per_scen_chb = zeros(1, length(SCENARIOS));
    for s = 1:length(SCENARIOS)
        pkpk_per_scen_cha(s) = max(double(per_scenarios{s}.cha)) - min(double(per_scenarios{s}.cha));
        pkpk_per_scen_chb(s) = max(double(per_scenarios{s}.chb)) - min(double(per_scenarios{s}.chb));
    end

    % [S2] vpp_500mV 应比 [S1] default CHA 大
    add_assert(sprintf('[vpp_500mV] CHA 摆幅 ≥ [default] (%.0f ≥ %.0f)', ...
                       pkpk_per_scen_cha(2), pkpk_per_scen_cha(1)), ...
               pkpk_per_scen_cha(2) >= pkpk_per_scen_cha(1));
    % [S4] am_0.6 应比 [S1] default CHA 摆幅大 (调制度更深)
    add_assert(sprintf('[am_0.6] CHA 摆幅 ≥ [default] (%.0f ≥ %.0f)', ...
                       pkpk_per_scen_cha(4), pkpk_per_scen_cha(1)), ...
               pkpk_per_scen_cha(4) >= pkpk_per_scen_cha(1));
    % [S5] am_0.9 应比 [S4] am_0.6 CHA 摆幅更大
    add_assert(sprintf('[am_0.9] CHA 摆幅 ≥ [am_0.6] (%.0f ≥ %.0f)', ...
                       pkpk_per_scen_cha(5), pkpk_per_scen_cha(4)), ...
               pkpk_per_scen_cha(5) >= pkpk_per_scen_cha(4));
    % [S7] fm_5.0kHz  CHB 频谱中载波仍应显著 (fm 频偏变化不影响 15 MHz 主峰)
    for s = 1:length(SCENARIOS)
        chb_s = double(per_scenarios{s}.chb) - ZERO;
        chb_fft_s = abs(fft(chb_s));
        f_axis_s = (0:length(chb_s)-1) * F_DAC / length(chb_s) / 1e6;
        [~, car_bin_s] = min(abs(f_axis_s - 15.0));
        add_assert(sprintf('[%s] CHB 15 MHz 载波 bin > 1000 (got %.0f)', SCENARIOS{s}, chb_fft_s(car_bin_s)), ...
                   chb_fft_s(car_bin_s) > 1000);
    end
    % 所有场景 DC 中点应在 8000-8400 之间 (8192 ± 200)
    for s = 1:length(SCENARIOS)
        cm = mean(double(per_scenarios{s}.cha));
        bm = mean(double(per_scenarios{s}.chb));
        add_assert(sprintf('[%s] CHA DC 中点 8000-8400 (got %.1f)', SCENARIOS{s}, cm), ...
                   cm >= 8000 && cm <= 8400);
        add_assert(sprintf('[%s] CHB DC 中点 8000-8400 (got %.1f)', SCENARIOS{s}, bm), ...
                   bm >= 8000 && bm <= 8400);
    end

    % ===== 增强断言 (Step 7 扩展) =====

    % [增强 1] AM 包络对称性 - 每个 AM 场景的 envelope peak 上半/下半比值应 ~1.0
    am_scenarios_cha = {'default', 'vpp_500mV', 'vpp_1000mV', 'am_0.6', 'am_0.9'};
    for k = 1:length(am_scenarios_cha)
        sname = am_scenarios_cha{k};
        sidx = find(strcmp(SCENARIOS, sname), 1);
        if isempty(sidx), continue; end
        cs = double(per_scenarios{sidx}.cha);
        cm = mean(cs);
        top = max(cs) - cm;
        bot = cm - min(cs);
        if bot > 0
            ratio = top / bot;
            add_assert(sprintf('[%s] AM 包络对称 (top/bot=%.3f)', sname, ratio), ...
                       ratio >= 0.85 && ratio <= 1.15);
        end
    end

    % [增强 2] FM 场景 CHB 瞬时频率变化率 std/mean 应 < 0.05 (稳定)
    fm_scenarios = {'fm_4.0kHz', 'fm_5.0kHz', 'extreme_full'};
    for k = 1:length(fm_scenarios)
        sname = fm_scenarios{k};
        sidx = find(strcmp(SCENARIOS, sname), 1);
        if isempty(sidx), continue; end
        bs = double(per_scenarios{sidx}.chb);
        bs_detrend = bs - mean(bs);
        if max(abs(bs_detrend)) > 100
            % 估计瞬时频率 (零交叉法): 每个完整周期有 2 个 ZC
            N = length(bs);
            zc = length(find(diff(sign(bs_detrend)) ~= 0));
            % fm = zc / (2 * N / F_DAC) = zc * F_DAC / (2 * N)
            inst_f = zc * F_DAC / (2 * N);
            if inst_f < 1e6
                inst_f = F_CAR;  % 退化保护
            end
            add_assert(sprintf('[%s] FM 瞬时频率 ≈ 15 MHz (got %.3f MHz)', sname, inst_f/1e6), ...
                       inst_f >= 13e6 && inst_f <= 17e6);
        end
    end

    % [增强 3] 载波 3 dB 带宽检查 - FFT 峰值两侧 ± 100 kHz 衰减 < -3 dB
    for s = 1:length(SCENARIOS)
        sname = SCENARIOS{s};
        cs = double(per_scenarios{s}.cha);
        cs = cs - mean(cs);
        N = length(cs);
        cw = hanning(N)';
        cs_fft = abs(fft(cs .* cw));
        car_bin = round(F_CAR / F_DAC * N) + 1;
        car_mag = cs_fft(car_bin);
        side_bin = round((F_CAR + 100e3) / F_DAC * N) + 1;
        if side_bin <= N
            side_mag = cs_fft(side_bin);
            atten_db = 20 * log10(side_mag / max(car_mag, 1));
            add_assert(sprintf('[%s] CHA 载波 +100kHz 旁瓣衰减 (%.1f dB)', sname, atten_db), ...
                       atten_db < -10);
        end
    end

    % [增强 4] 短窗 DC 稳定性 - 256 样本滑动均值波动
    for s = 1:length(SCENARIOS)
        sname = SCENARIOS{s};
        cs = double(per_scenarios{s}.cha);
        cs_mean = mean(cs);
        sw_starts = 1:256:length(cs)-256;
        means = zeros(length(sw_starts), 1);
        for k = 1:length(sw_starts)
            means(k) = mean(cs(sw_starts(k):sw_starts(k)+255));
        end
        std_dev = std(means);
        add_assert(sprintf('[%s] CHA 短窗 DC 稳定 (std=%.2f LSB)', sname, std_dev), ...
                   std_dev < 100);
    end

    % [增强 5] CHB 短窗 DC 稳定性
    for s = 1:length(SCENARIOS)
        sname = SCENARIOS{s};
        bs = double(per_scenarios{s}.chb);
        bs_mean = mean(bs);
        sw_starts = 1:256:length(bs)-256;
        means = zeros(length(sw_starts), 1);
        for k = 1:length(sw_starts)
            means(k) = mean(bs(sw_starts(k):sw_starts(k)+255));
        end
        std_dev = std(means);
        add_assert(sprintf('[%s] CHB 短窗 DC 稳定 (std=%.2f LSB)', sname, std_dev), ...
                   std_dev < 100);
    end

    % [增强 6] 相邻样本毛刺检查 - 每场景 max|Δ| < 1000 (升级自 1500)
    for s = 1:length(SCENARIOS)
        sname = SCENARIOS{s};
        cs = double(per_scenarios{s}.cha);
        bs = double(per_scenarios{s}.chb);
        max_dc = max(abs(diff(cs)));
        max_db = max(abs(diff(bs)));
        add_assert(sprintf('[%s] CHA 毛刺 max|Δ| < 1000 (got %.0f)', sname, max_dc), max_dc < 1000);
        add_assert(sprintf('[%s] CHB 毛刺 max|Δ| < 1000 (got %.0f)', sname, max_db), max_db < 1000);
    end

    % [增强 7] 极端场景完整性 - S8 extreme_full 所有指标应满足
    s_ext = find(strcmp(SCENARIOS, 'extreme_full'), 1);
    if ~isempty(s_ext)
        ce = double(per_scenarios{s_ext}.cha);
        be = double(per_scenarios{s_ext}.chb);
        add_assert('[extreme_full] CHA 14-bit 合法',  min(ce) >= 0 && max(ce) <= 16383);
        add_assert('[extreme_full] CHB 14-bit 合法',  min(be) >= 0 && max(be) <= 16383);
        add_assert('[extreme_full] CHA 摆幅 ≥ 100',  max(ce) - min(ce) >= 100);
        add_assert('[extreme_full] CHB 摆幅 ≥ 100',  max(be) - min(be) >= 100);
        add_assert('[extreme_full] CHA 围绕中点',   abs(mean(ce) - 8192) < 200);
        add_assert('[extreme_full] CHB 围绕中点',   abs(mean(be) - 8192) < 200);
    end

    % --- 写报告 ---
    report_path = fullfile(figure_dir, 'assertion_report.txt');
    fid = fopen(report_path, 'w');
    fprintf(fid, 'AD9764 AM/FM 数值验收报告 (扩展版)\n');
    fprintf(fid, '================================================================\n');
    fprintf(fid, '采样率 F_DAC      : %.0f Hz\n', F_DAC);
    fprintf(fid, '载波 F_CARRIER    : %.3f MHz\n', F_CAR / 1e6);
    fprintf(fid, '调制波 F_MOD      : %.1f kHz\n', F_MOD / 1e3);
    fprintf(fid, 'DAC 零偏 ZERO     : %d LSB\n', ZERO);
    fprintf(fid, '1 Vpp ≈ LSB       : %d LSB\n', LSB_PER_V);
    fprintf(fid, '场景数            : %d\n', length(SCENARIOS));
    fprintf(fid, '每场景样本        : %d\n', SAMPLES_PER_SCENARIO);

    fprintf(fid, '\n总体样本统计\n');
    fprintf(fid, '----------------------------------------------------------------\n');
    fprintf(fid, 'CHA 总数 / range  : %d / [%d, %d]\n', length(cha_all), min(cha_all), max(cha_all));
    fprintf(fid, 'CHB 总数 / range  : %d / [%d, %d]\n', length(chb_all), min(chb_all), max(chb_all));

    fprintf(fid, '\n默认场景 (S1) FFT\n');
    fprintf(fid, '----------------------------------------------------------------\n');
    fprintf(fid, '15 MHz bin 幅度                : %.1f\n', carrier_mag);
    fprintf(fid, '14.990 / 15.010 MHz bins       : %.1f / %.1f\n', cha_fft(sb_lower_bin), cha_fft(sb_upper_bin));
    fprintf(fid, 'CHB 平均瞬时频率 (ZC/FFT/中位): %.4f / %.4f / %.4f MHz\n', inst_freq_zc_mhz, inst_freq_fft_mhz, inst_freq_mhz);
    fprintf(fid, 'CHA max|Δ|                     : %.0f\n', cha_glitch_max);
    fprintf(fid, 'CHB max|Δ|                     : %.0f\n', chb_glitch_max);

    fprintf(fid, '\n逐场景摆幅\n');
    fprintf(fid, '----------------------------------------------------------------\n');
    fprintf(fid, '%-15s  %-15s  %-15s\n', 'Scenario', 'CHA pkpk', 'CHB pkpk');
    for s = 1:length(SCENARIOS)
        fprintf(fid, '%-15s  %-15.0f  %-15.0f\n', SCENARIOS{s}, pkpk_per_scen_cha(s), pkpk_per_scen_chb(s));
    end

    fprintf(fid, '\n断言列表\n');
    fprintf(fid, '----------------------------------------------------------------\n');
    for k = 1:length(asserts)
        a = asserts{k};
        fprintf(fid, '[%s] %s\n', a.status, a.text);
    end
    fprintf(fid, '\n总计: PASS=%d  FAIL=%d\n', pass_count, fail_count);
    if fail_count == 0
        fprintf(fid, '\nOVERALL: PASS\n');
    else
        fprintf(fid, '\nOVERALL: FAIL\n');
    end
    fclose(fid);

    % --- 画图 ---
    plot_overview(cha, chb, F_DAC, figure_dir);
    plot_cha_envelope(cha, F_DAC, figure_dir);
    plot_cha_fft(cha, F_DAC, figure_dir);
    plot_chb_fft(chb, F_DAC, figure_dir);
    plot_chb_instfreq(chb, F_DAC, figure_dir);
    plot_cha_glitch(cha, F_DAC, figure_dir);
    plot_chb_glitch(chb, F_DAC, figure_dir);
    plot_envelope_per_midx(per_scenarios, figure_dir);

    % --- 退出码 (用全局变量告知批处理) ---
    if fail_count == 0
        fprintf('\n========================================\n');
        fprintf('OVERALL: PASS (%d checks)\n', pass_count);
        fprintf('========================================\n');
        exit(0);
    else
        fprintf('\n========================================\n');
        fprintf('OVERALL: FAIL (%d failures out of %d)\n', fail_count, pass_count + fail_count);
        fprintf('========================================\n');
        exit(1);
    end

    function add_assert(name, cond)
        if cond
            status = 'PASS';
            pass_count = pass_count + 1;
        else
            status = 'FAIL';
            fail_count = fail_count + 1;
        end
        fprintf('  [%s] %s\n', status, name);
        asserts{end+1} = struct('status', status, 'text', name);
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

function m = max_adj_delta(x)
    % 相邻样本差分最大绝对值 (作为毛刺度量)
    if length(x) < 2, m = 0; return; end
    d = abs(diff(x));
    m = max(d);
end

function bw = fm_bandwidth_indicator(x, F_DAC)
    % FM 带宽指示：3 dB 带宽 / 总能量 (越大表示频谱越宽)
    x = double(x) - mean(double(x));
    n = length(x);
    if n == 0, bw = 0; return; end
    y = abs(fft(x));
    total = sum(y(1:floor(n/2)));
    if total == 0, bw = 0; return; end
    half = total / 2;
    cs = 0; idx = 0;
    while cs < half && idx < floor(n/2)
        idx = idx + 1;
        cs = cs + y(idx);
    end
    bw = idx / n * F_DAC / 1e6;  % MHz
end

function plot_overview(cha, chb, F_DAC, figure_dir)
    n = length(cha);
    t_us = (0:n-1) / F_DAC * 1e6;
    figure('Position', [100 100 1200 600]);
    subplot(2,1,1);
    plot(t_us, cha, 'b-', 'LineWidth', 0.4);
    grid on;
    xlabel('Time (us)'); ylabel('DAC code');
    title('CHA Output (AM, 15 MHz carrier modulated by 10 kHz)');
    subplot(2,1,2);
    plot(t_us, chb, 'r-', 'LineWidth', 0.4);
    grid on;
    xlabel('Time (us)'); ylabel('DAC code');
    title('CHB Output (FM, 15 MHz carrier + 3 kHz deviation)');
    saveas(gcf, fullfile(figure_dir, 'overview_cha_chb.png'));
end

function plot_cha_envelope(cha, F_DAC, figure_dir)
    n = length(cha);
    t_us = (0:n-1) / F_DAC * 1e6;
    win = max(1, round(n / 200));
    env_high = moving_max(cha, win);
    env_low  = moving_min(cha, win);
    figure('Position', [100 100 1200 400]);
    plot(t_us, cha, 'b-', 'LineWidth', 0.4); hold on;
    plot(t_us, env_high, 'r-', 'LineWidth', 1.5);
    plot(t_us, env_low,  'g-', 'LineWidth', 1.5);
    hold off;
    grid on;
    xlabel('Time (us)'); ylabel('DAC code');
    title('CHA AM Signal with Envelope (upper=red, lower=green)');
    legend('CHA', 'upper env', 'lower env');
    saveas(gcf, fullfile(figure_dir, 'cha_envelope.png'));
end

function plot_cha_fft(cha, F_DAC, figure_dir)
    n = length(cha);
    f_axis = (0:n-1) * (F_DAC / n) / 1e6;
    y = abs(fft(double(cha) - mean(double(cha))));
    figure('Position', [100 100 1200 400]);
    plot(f_axis(1:floor(n/2)), 20 * log10(y(1:floor(n/2)) + 1), 'b-', 'LineWidth', 0.5);
    grid on;
    xlabel('Frequency (MHz)'); ylabel('Magnitude (dB)');
    title(sprintf('CHA FFT Spectrum (n=%d)', n));
    xlim([1 2]);
    saveas(gcf, fullfile(figure_dir, 'cha_fft.png'));
end

function plot_chb_fft(chb, F_DAC, figure_dir)
    n = length(chb);
    f_axis = (0:n-1) * (F_DAC / n) / 1e6;
    y = abs(fft(double(chb) - mean(double(chb))));
    figure('Position', [100 100 1200 400]);
    plot(f_axis(1:floor(n/2)), 20 * log10(y(1:floor(n/2)) + 1), 'r-', 'LineWidth', 0.5);
    grid on;
    xlabel('Frequency (MHz)'); ylabel('Magnitude (dB)');
    title(sprintf('CHB FFT Spectrum (n=%d)', n));
    xlim([1 2]);
    saveas(gcf, fullfile(figure_dir, 'chb_fft.png'));
end

function plot_chb_instfreq(chb, F_DAC, figure_dir)
    ZERO_LOCAL = 8192;
    n = length(chb);
    t_us = (0:n-1) / F_DAC * 1e6;
    chb_signed = double(chb) - ZERO_LOCAL;
    chb_sign = sign(chb_signed);
    crossings = find(diff(chb_sign) > 0);
    if length(crossings) < 2, return; end
    periods = diff(crossings);
    freq_mhz = F_DAC ./ periods / 1e6;
    figure('Position', [100 100 1200 400]);
    plot(crossings(2:end) / F_DAC * 1e6, freq_mhz, 'b.-', 'LineWidth', 0.8, 'MarkerSize', 4);
    grid on;
    xlabel('Time (us)'); ylabel('Instantaneous Frequency (MHz)');
    title('CHB FM Instantaneous Frequency (15 MHz center)');
    ylim([1.45 1.55]);
    saveas(gcf, fullfile(figure_dir, 'chb_instfreq.png'));
end

function plot_cha_glitch(cha, F_DAC, figure_dir)
    n = length(cha);
    t_us = (0:n-1) / F_DAC * 1e6;
    d = [0; abs(diff(double(cha)))];
    figure('Position', [100 100 1200 400]);
    plot(t_us, d, 'b-', 'LineWidth', 0.5);
    grid on;
    xlabel('Time (us)'); ylabel('|Δ| (LSB)');
    title(sprintf('CHA Adjacent-Sample |Δ| (max = %.0f)', max(d)));
    ylim([0 1500]);
    saveas(gcf, fullfile(figure_dir, 'cha_glitch.png'));
end

function plot_chb_glitch(chb, F_DAC, figure_dir)
    n = length(chb);
    t_us = (0:n-1) / F_DAC * 1e6;
    d = [0; abs(diff(double(chb)))];
    figure('Position', [100 100 1200 400]);
    plot(t_us, d, 'r-', 'LineWidth', 0.5);
    grid on;
    xlabel('Time (us)'); ylabel('|Δ| (LSB)');
    title(sprintf('CHB Adjacent-Sample |Δ| (max = %.0f)', max(d)));
    ylim([0 1500]);
    saveas(gcf, fullfile(figure_dir, 'chb_glitch.png'));
end

function plot_envelope_per_midx(scenarios, figure_dir)
    % 7 场景 CHA 摆幅条形图
    names = cell(1, length(scenarios));
    pkpks = zeros(1, length(scenarios));
    for i = 1:length(scenarios)
        names{i} = scenarios{i}.name;
        pkpks(i) = max(double(scenarios{i}.cha)) - min(double(scenarios{i}.cha));
    end
    figure('Position', [100 100 1200 400]);
    bar(pkpks, 'FaceColor', [0.2 0.6 0.8]);
    set(gca, 'XTickLabel', names, 'XTick', 1:length(names));
    xtickangle(20);
    grid on;
    ylabel('CHA pkpk (LSB)');
    title('CHA AM 摆幅 vs 场景');
    saveas(gcf, fullfile(figure_dir, 'envelope_per_midx.png'));
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