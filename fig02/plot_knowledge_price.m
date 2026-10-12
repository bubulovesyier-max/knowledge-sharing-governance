%% fig2_four_independent_figures_time_history.m
% 功能：
% 读取同一文件夹下的 Excel 数据，并绘制四个独立的图。
%
% 四个独立图分别为：
% Figure 1: rho_A(t)
% Figure 2: rho_B(t)
% Figure 3: rho_C(t)
% Figure 4: rho_D(t)
%
% 每个图中，不同曲线表示不同的 p 或 s 参数值。
%
% 修改：
% 1. 删除 p=1.2 曲线；
% 2. 数学符号统一使用 LaTeX；
% 3. 坐标刻度使用 Times New Roman；
% 4. 所有文字均不加粗；
% 5. 保持原有字体大小不变；
% 6. 保留原有 lines() 配色，不修改颜色。

clear;
clc;
close all;


%% =========================================================
% 1. 找到当前 m 文件所在文件夹
% ==========================================================

thisFile = mfilename('fullpath');

if isempty(thisFile)
    dataFolder = pwd;
else
    dataFolder = fileparts(thisFile);
end


%% =========================================================
% 2. 读取 Excel 文件
% ==========================================================

xlsxFiles = dir(fullfile(dataFolder, '*.xlsx'));

% 排除 Excel 临时文件
if ~isempty(xlsxFiles)

    fileNames = {xlsxFiles.name};

    temporaryFlag = startsWith(fileNames, '~$');

    xlsxFiles = xlsxFiles(~temporaryFlag);

end


if isempty(xlsxFiles)

    error(['当前文件夹下没有找到 .xlsx 文件，', ...
        '请把 Excel 数据和本 m 文件放在同一个文件夹下。']);

end


% 自动读取第一个 Excel 文件
xlsxFile = fullfile(dataFolder, xlsxFiles(1).name);

% 如果想手动指定文件名，可使用：
% xlsxFile = fullfile(dataFolder, 'p不同.xlsx');


fprintf('正在读取数据文件：%s\n', xlsxFile);


sheetName = 1;

raw = readcell( ...
    xlsxFile, ...
    'Sheet', sheetName);


%% =========================================================
% 3. 基本设置
% ==========================================================

paramRow     = 2;   % 参数所在行，例如 p=0.2
strategyRow  = 3;   % A、B、C、D 所在行
dataStartRow = 4;   % 数据开始行


[nRows, nCols] = size(raw);


if nRows < dataStartRow

    error('Excel 数据行数不足，请检查参数行、策略行和数据行。');

end


%% =========================================================
% 4. 读取第 2 行参数标签
% ==========================================================

headerStr = strings(1, nCols);


for j = 1:nCols

    value = raw{paramRow, j};

    headerStr(j) = safeCellToString(value);

end


%% =========================================================
% 5. 找到参数起始列
% ==========================================================

% 优先识别 p= 或 s=
paramCols = find( ...
    contains(headerStr, "p=", 'IgnoreCase', true) | ...
    contains(headerStr, "s=", 'IgnoreCase', true));


% 如果没有识别到 p= 或 s=
if isempty(paramCols)

    strategyStr = strings(1, nCols);


    for j = 1:nCols

        strategyStr(j) = ...
            safeCellToString(raw{strategyRow, j});

    end


    paramCols = find(strcmpi(strategyStr, "A"));


    if isempty(paramCols)

        error(['未能识别参数起始列。请确认第 2 行包含 ', ...
            'p=0.2 或 s=2，且第 3 行包含 A、B、C、D。']);

    end


    warning(['未识别到 p= 或 s= 标签，', ...
        '已根据第 3 行的 A 列识别参数组。']);

end


numParams = numel(paramCols);


%% =========================================================
% 6. 判断参数类型 p 或 s，并提取参数值
% ==========================================================

if any(contains( ...
        headerStr(paramCols), ...
        "p=", ...
        'IgnoreCase', true))

    paramSymbol = 'p';


elseif any(contains( ...
        headerStr(paramCols), ...
        "s=", ...
        'IgnoreCase', true))

    paramSymbol = 's';


else

    paramSymbol = 'parameter';

end


paramValues = nan(numParams, 1);


for k = 1:numParams

    labelText = char(headerStr(paramCols(k)));


    token = regexp( ...
        labelText, ...
        '[-+]?\d*\.?\d+(?:[eE][-+]?\d+)?', ...
        'match');


    if ~isempty(token)

        paramValues(k) = str2double(token{1});

    else

        paramValues(k) = k;

    end

end


%% =========================================================
% 7. 读取每个参数下的时间序列数据
% ==========================================================

dataAll = cell(numParams, 1);


for k = 1:numParams

    c0 = paramCols(k);


    % 判断该参数组是否带有 t 列
    strategy0 = ...
        safeCellToString(raw{strategyRow, c0});


    hasTimeColumn = false;


    if strcmpi(strategy0, "t") || ...
       strcmpi(strategy0, "time") || ...
       strcmp(strategy0, "时间")

        hasTimeColumn = true;

    end


    if hasTimeColumn

        timeCol = c0;

        dataCols = c0 + 1:c0 + 4;

    else

        timeCol = [];

        dataCols = c0:c0 + 3;

    end


    if dataCols(end) > nCols

        error( ...
            '参数组 %d 后方不足 4 列，无法读取 A、B、C、D。', ...
            k);

    end


    %% -----------------------------------------------------
    % 7.1 读取策略比例数据
    % ------------------------------------------------------

    yRaw = raw(dataStartRow:end, dataCols);


    y = cellBlockToDouble(yRaw);


    % 至少存在一个有效值
    validDataRows = any(~isnan(y), 2);


    % 四列都必须有有效值
    completeDataRows = all(~isnan(y), 2);


    validRows = ...
        validDataRows & completeDataRows;


    y = y(validRows, :);


    if isempty(y)

        error( ...
            '参数组 %d 没有读取到有效数值数据。', ...
            k);

    end


    %% -----------------------------------------------------
    % 7.2 读取时间数据
    % ------------------------------------------------------

    if hasTimeColumn

        tRaw = raw(dataStartRow:end, timeCol);


        tAll = cellBlockToDouble(tRaw);


        t = tAll(validRows, :);


        validTimeRows = ~isnan(t);


        t = t(validTimeRows);


        y = y(validTimeRows, :);


        if isempty(t)

            error( ...
                '参数组 %d 的时间列没有读取到有效数据。', ...
                k);

        end


    else

        % 如果 Excel 没有时间列，则默认从 0 开始
        t = (0:size(y, 1)-1)';

    end


    dataAll{k}.t = t;

    dataAll{k}.rho = y;

end


%% =========================================================
% 8. 按参数值从小到大排序
% ==========================================================

[paramValues, order] = sort(paramValues);

dataAll = dataAll(order);


%% =========================================================
% 9. 设置颜色并删除 p=1.2
% ==========================================================

% 先生成原始颜色，再删除 p=1.2 对应颜色，
% 从而保证其他参数的颜色不发生变化。

colors = lines(numParams);


if strcmp(paramSymbol, 'p')

    tolerance = 1e-10;


    keepMask = ...
        abs(paramValues - 1.2) > tolerance;


    if any(~keepMask)

        fprintf('已删除 p=1.2 对应的曲线。\n');

    end


    paramValues = paramValues(keepMask);

    dataAll = dataAll(keepMask);

    colors = colors(keepMask, :);


    numParams = numel(paramValues);

end


%% =========================================================
% 10. 作图设置
% ==========================================================

% 每个时间步都绘制
plotEvery = 1;

% 如果数据量过大，可以改为：
% plotEvery = 10;


% 数学符号统一使用 LaTeX
strategyNames = {
    '$\rho_A$'
    '$\rho_B$'
    '$\rho_C$'
    '$\rho_D$'
};


figureNames = {
    'rho_A(t)'
    'rho_B(t)'
    'rho_C(t)'
    'rho_D(t)'
};


%% =========================================================
% 11. 设置图例
% ==========================================================

legendLabels = cell(numParams, 1);


for k = 1:numParams

    if strcmp(paramSymbol, 'p')

        legendLabels{k} = sprintf( ...
            '$p=%.2g$', ...
            paramValues(k));


    elseif strcmp(paramSymbol, 's')

        legendLabels{k} = sprintf( ...
            '$s=%.2g$', ...
            paramValues(k));


    else

        legendLabels{k} = sprintf( ...
            'Parameter = %.2g', ...
            paramValues(k));

    end

end


%% =========================================================
% 12. 绘制四个独立的图
% ==========================================================

% 每一行为：
% [左 下 宽 高]
% 单位：厘米

figurePositions = [
     3, 12, 14, 10
    18, 12, 14, 10
     3,  1, 14, 10
    18,  1, 14, 10
];


for strategyIdx = 1:4

    figure( ...
        'Color', 'w', ...
        'Units', 'centimeters', ...
        'Position', figurePositions(strategyIdx, :), ...
        'Name', figureNames{strategyIdx}, ...
        'NumberTitle', 'off');


    ax = gca;


    hold(ax, 'on');


    lineHandles = gobjects(numParams, 1);


    for k = 1:numParams

        t = dataAll{k}.t;


        y = dataAll{k}.rho(:, strategyIdx);


        % 确保时间和策略数据长度一致
        minLength = min( ...
            length(t), ...
            length(y));


        t = t(1:minLength);


        y = y(1:minLength);


        % 按指定间隔选取数据
        idx = 1:plotEvery:minLength;


        lineHandles(k) = plot( ...
            ax, ...
            t(idx), ...
            y(idx), ...
            'LineWidth', 1.8, ...
            'Color', colors(k, :));

    end


    hold(ax, 'off');


    %% -----------------------------------------------------
    % 坐标轴设置
    % ------------------------------------------------------

    grid(ax, 'off');


    box(ax, 'on');


    ylim(ax, [0, 1]);


    %% -----------------------------------------------------
    % 横轴
    % 数学符号使用 LaTeX
    % 字号保持 18
    % 不加粗
    % ------------------------------------------------------

    xlabel( ...
        ax, ...
        '$t$', ...
        'Interpreter', 'latex', ...
        'FontSize', 18, ...
        'FontWeight', 'normal');


    %% -----------------------------------------------------
    % 纵轴
    % 数学符号使用 LaTeX
    % 字号保持 18
    % 不加粗
    % ------------------------------------------------------

    ylabel( ...
        ax, ...
        strategyNames{strategyIdx}, ...
        'Interpreter', 'latex', ...
        'FontSize', 18, ...
        'FontWeight', 'normal');


    %% -----------------------------------------------------
    % 图例
    % 数学符号使用 LaTeX
    % 字号保持 16
    % 不加粗
    % ------------------------------------------------------

    lgd = legend( ...
        ax, ...
        lineHandles, ...
        legendLabels, ...
        'Interpreter', 'latex', ...
        'Location', 'best', ...
        'FontSize', 16, ...
        'FontWeight', 'normal', ...
        'Box', 'on');


    % 防止图例自动改变
    set( ...
        lgd, ...
        'AutoUpdate', 'off', ...
        'Visible', 'on');


    %% -----------------------------------------------------
    % 坐标刻度
    % Times New Roman
    % 字号保持 18
    % 不加粗
    % ------------------------------------------------------

    set( ...
        ax, ...
        'FontName', 'Times New Roman', ...
        'FontSize', 18, ...
        'FontWeight', 'normal', ...
        'LineWidth', 1.4, ...
        'TickDir', 'in', ...
        'Layer', 'top');


    drawnow;

end


%% =========================================================
% 13. 在命令行输出每个参数的最终策略比例
% ==========================================================

fprintf('\n最终时刻策略比例：\n');


finalResult = nan(numParams, 5);


for k = 1:numParams

    finalRho = ...
        dataAll{k}.rho(end, :);


    finalResult(k, :) = [
        paramValues(k), ...
        finalRho
    ];

end


resultTable = array2table( ...
    finalResult, ...
    'VariableNames', {
        paramSymbol, ...
        'rhoA', ...
        'rhoB', ...
        'rhoC', ...
        'rhoD'
    });


disp(resultTable);


%% =========================================================
% 辅助函数 1：
% 安全转换单元格为字符串
% ==========================================================

function str = safeCellToString(value)

    if isempty(value)

        str = "";
        return;

    end


    if isnumeric(value)

        if all(isnan(value(:)))

            str = "";

        else

            str = string(value);

        end

        return;

    end


    if ischar(value)

        str = string(strtrim(value));

        return;

    end


    if isstring(value)

        if all(ismissing(value(:)))

            str = "";

        else

            str = strtrim(value);

        end

        return;

    end


    try

        missingFlag = ismissing(value);


        if all(missingFlag(:))

            str = "";

        else

            str = string(value);

        end


    catch

        str = string(value);

    end


    str = strtrim(str);

end


%% =========================================================
% 辅助函数 2：
% 将 cell 数组转换为 double 数组
% ==========================================================

function numMat = cellBlockToDouble(cellBlock)

    [r, c] = size(cellBlock);


    numMat = nan(r, c);


    for ii = 1:r

        for jj = 1:c

            value = cellBlock{ii, jj};


            if isempty(value)

                numMat(ii, jj) = NaN;


            elseif isnumeric(value)

                if isscalar(value)

                    numMat(ii, jj) = value;

                else

                    numMat(ii, jj) = NaN;

                end


            elseif ischar(value)

                tmp = str2double(strtrim(value));


                if ~isnan(tmp)

                    numMat(ii, jj) = tmp;

                else

                    numMat(ii, jj) = NaN;

                end


            elseif isstring(value)

                if all(ismissing(value(:)))

                    numMat(ii, jj) = NaN;

                else

                    tmp = str2double(strtrim(value));


                    if isscalar(tmp) && ~isnan(tmp)

                        numMat(ii, jj) = tmp;

                    else

                        numMat(ii, jj) = NaN;

                    end

                end


            else

                try

                    tmp = str2double(string(value));


                    if isscalar(tmp) && ~isnan(tmp)

                        numMat(ii, jj) = tmp;

                    else

                        numMat(ii, jj) = NaN;

                    end


                catch

                    numMat(ii, jj) = NaN;

                end

            end

        end

    end

end