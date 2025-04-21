%% DJI MRK Point Aggregator and Renamer Tool
% Version 1.0
% Author: Evan Chang
% Description: Aggregates and renames photo points from DJI M3E .MRK files
%              found in subdirectories and exports a unified CSV file.

% === DJI M3E MRK 整合工具 ===
% 功能：整合當前資料夾與所有子資料夾內的 .MRK 檔案
%   1. 擷取檔名中的點位前綴
%   2. 為每筆紀錄重新命名點位
%   3. 合併寫入 combined.csv，並完成欄位解析

% Input: 子目錄中所有MRK檔案
% Output: combined.csv

%% Step 1: 搜尋所有 .MRK 檔案
files = dir(fullfile(pwd, '**', '*.MRK'));
allData = {};  % 儲存所有資料列

%% Step 2: 逐一讀取與處理每個 MRK 檔案
for i = 1:length(files)
    filePath = fullfile(files(i).folder, files(i).name);

    % === 擷取點位前綴 ===
    nameParts = split(files(i).name, '_');
    if length(nameParts) < 4
        warning('檔名格式不符，略過此檔案：%s', files(i).name);
        continue;
    end

    rawName = nameParts{4};

    if contains(rawName, 'modified')
        prefixName = extractBefore(rawName, 'modified');
    else
        prefixName = erase(rawName, '.MRK');
    end

    pointPrefix = strcat(nameParts{3}, '_', prefixName);

    % === 開啟並逐行讀取檔案 ===
    fid = fopen(filePath, 'r');
    if fid == -1
        warning('無法開啟檔案：%s', filePath);
        continue;
    end

    lineNum = 0;
    while ~feof(fid)
        line = fgetl(fid);
        lineNum = lineNum + 1;

        newPointName = sprintf('%s_%d', pointPrefix, lineNum);
        newLine = sprintf('%s,%s', newPointName, line);
        allData{end+1, 1} = newLine;
    end
    fclose(fid);
end

%% Step 3: 寫入暫存 CSV（初步合併）
tempOutput = 'combined.csv';
fid = fopen(tempOutput, 'w');
for i = 1:length(allData)
    fprintf(fid, '%s\n', allData{i});
end
fclose(fid);
disp(['初步整合完成，共寫入 ', num2str(length(allData)), ' 筆資料。']);

%% Step 4: 欄位解析與格式化
opts = detectImportOptions(tempOutput, 'Encoding', 'UTF-8');
T_raw = readtable(tempOutput, opts, 'ReadVariableNames', false);

% 預留欄位
numRows = height(T_raw);
[PointName, Col2, Col3, N, E, V] = deal(strings(numRows, 1));
[Lat, Lon, Ellh, SigmaXY] = deal(nan(numRows, 1));
[SigmaX, SigmaY, FixStatus] = deal(strings(numRows, 1));

for i = 1:numRows
    row = table2cell(T_raw(i, :));
    tokens = split(string(row{1}), ',');

    PointName(i) = tokens(1);
    Col2(i) = str2double(row{2});
    Col3(i) = string(row{3});
    N(i) = string(row{4});
    E(i) = string(row{5});
    V(i) = string(row{6});
    Lat(i) = extractMRKNumber(row{7}, 'Lat');
    Lon(i) = extractMRKNumber(row{8}, 'Lon');
    Ellh(i) = extractMRKNumber(row{9}, 'Ellh');
    SigmaX(i) = extractBefore(string(row{10}), ',');
    SigmaY(i) = extractBefore(string(row{11}), ',');
    SigmaXY(i) = str2double(row{12});
    FixStatus(i) = string(row{13});
end

% 清理方向欄位資料（去掉逗號與後綴）
N = extractBefore(N, ',');
E = extractBefore(E, ',');
V = extractBefore(V, ',');

%% Step 5: 整合成結構化表格並輸出
T = table(PointName, Col2, Col3, N, E, V, Lat, Lon, Ellh, ...
          SigmaX, SigmaY, SigmaXY, FixStatus);

% 寫入最終 UTF-8 with BOM 的 CSV 檔
finalOutput = 'combined.csv';
fid = fopen(finalOutput, 'w', 'n', 'UTF-8');
fwrite(fid, char([239 187 191]), 'char');  % 寫入 UTF-8 BOM
fclose(fid);
writetable(T, finalOutput);

disp("完整整合與欄位解析完成！輸出檔案：combined.csv");

%% 函式：擷取特定欄位中的數值
function val = extractMRKNumber(field, keyword)
    if ischar(field), field = string(field); end
    searchTerm = strcat(",", keyword);
    if contains(field, searchTerm)
        val = str2double(extractBefore(field, searchTerm));
    else
        val = NaN;
    end
end
