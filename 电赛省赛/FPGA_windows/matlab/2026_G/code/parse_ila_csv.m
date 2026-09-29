% parse_ila_csv.m — 独立函数，解析 Vivado ILA 导出的 CSV
%   输入: CSV 文件路径
%   输出: mag_table (containers.Map<bin, mag>), adc_vals (双精度数组)
%
% Vivado ILA CSV 标准格式:
%   row 1    : header (e.g. "Sample in Buffer,Sample in Window,...,ila_probe_mag[15:0],ila_probe_bin[10:0],ila_probe_valid,ila_probe_adc[11:0]")
%   row 2    : radix  (e.g. "Radix - UNSIGNED,UNSIGNED,...,HEX,HEX,HEX,HEX,HEX")
%   row 3+   : data   (十六进制, 逗号分隔)
%
% 注:
%   - BinSelect 输出 max 2560 个 bin 通道，每帧输出 8192 bin
%   - ILA 抓 multi-frame 数据时, mag_table 中只保留每个 bin 的最大 mag
%   - 默认只采集 valid=1 且 mag>0 的样点 (过滤 ILA 早期 trigger 前的空占位)

function [mag_table, adc_vals] = parse_ila_csv(csv_path)
    fid = fopen(csv_path, 'r');
    if fid < 0, error('Open failed: %s', csv_path); end
    raw = textscan(fid, '%s', 'Delimiter', '\n');
    fclose(fid);
    lines = strtrim(raw{1});
    if isempty(lines), error('Empty CSV: %s', csv_path); end

    % 找第一行真正的表头
    header_i = 0;
    for k = 1:length(lines)
        ln = lines{k};
        if isempty(ln), continue; end
        if strncmp(ln, '#', 1), continue; end
        if ~isempty(strfind(lower(ln), 'radix')), continue; end
        header_i = k; break;
    end
    if header_i == 0, error('No header line found in %s', csv_path); end

    hdr = strsplit(lines{header_i}, ',');
    hdr = strtrim(hdr);
    hdr = hdr(~cellfun(@isempty, hdr));
    fprintf('[parse] hdr: %s\n', strjoin(hdr, ' | '));
    lc = lower(hdr);

    mag_col   = find_col(lc, 'mag',   4);
    bin_col   = find_col(lc, 'bin',   5);
    valid_col = find_col(lc, 'valid', 6);
    adc_col   = find_col(lc, 'adc',   7);
    fprintf('[parse] cols: mag=%d bin=%d valid=%d adc=%d\n', ...
        mag_col, bin_col, valid_col, adc_col);

    mag_table = containers.Map('KeyType','uint32','ValueType','double');
    adc_vals  = [];

    data_start = header_i + 1;
    for i = data_start:length(lines)
        ln = lines{i};
        if isempty(ln), continue; end
        if strncmp(ln, '#', 1), continue; end
        if ~isempty(strfind(lower(ln), 'radix')), continue; end
        if isempty(strfind(ln, ',')), continue; end
        parts = strsplit(ln, {',', ' ', '\t'});
        parts = parts(~cellfun(@isempty, parts));
        if length(parts) < max([mag_col, bin_col, valid_col, adc_col])
            continue;
        end
        try
            mag_v   = hex2dec(strip0x(parts{mag_col}));
            bin_v   = hex2dec(strip0x(parts{bin_col}));
            valid_v = hex2dec(strip0x(parts{valid_col}));
            adc_v   = hex2dec(strip0x(parts{adc_col}));
        catch
            continue;
        end
        if valid_v > 0 && mag_v > 0
            k = uint32(bin_v);
            if mag_table.isKey(k)
                if mag_table(k) < mag_v, mag_table(k) = mag_v; end
            else
                mag_table(k) = mag_v;
            end
        end
        adc_vals(end+1) = adc_v; %#ok<AGROW>
    end
end

function c = find_col(lc, needle, fallback)
    for j = 1:length(lc)
        if ~isempty(strfind(lc{j}, needle))
            c = j; return;
        end
    end
    c = fallback;
end

function out = strip0x(s)
    out = strtrim(s);
    if length(out) > 2 && (strcmpi(out(1:2),'0x') || strcmpi(out(1:2),'0X'))
        out = out(3:end);
    end
end
