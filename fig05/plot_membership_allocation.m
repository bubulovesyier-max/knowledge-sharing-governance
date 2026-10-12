%% plot_r_steady_BC_standard.m
% 功能：
% 读取不同 r 参数下的策略比例时间序列，
% 使用最后 10% 数据的平均值计算稳态比例，
% 绘制 rho_B^* 和 rho_C^* 随 r 变化的普通折线图。
%
% 统一绘图格式：
% 1. 数学符号统一使用 LaTeX；
% 2. 普通英文和坐标刻度使用 Times New Roman；
% 3. 所有文字均不加粗；
% 4. 保持原有字体大小 16 不变；
% 5. 保持原有颜色、线型和 Marker 不变；
% 6. 图窗调整为 14 cm × 10 cm，使图形更加紧凑。
%
% Excel 格式：
% 第 1 行：说明文字，可有可无
% 第 2 行：参数标签，例如 r=0.2、r=0.4、r=0.6、r=0.8
% 第 3 行：策略标签 A、B、C、D
% 第 4 行及以后：策略比例时间序列
%
% 每组参数通常占 4 列：
% r=0.2              r=0.4
% A  B  C  D         A  B  C  D

clear;
clc;
close all;


%% =========================================================
% 1. 获取当前 m 文件所在文件夹
% ==========================================================

thisFile = mfilename('fullpath');

if isempty(thisFile)
    dataFolder = pwd;
else
    dataFolder = fileparts(thisFile);
end


%% =========================================================
% 2. 查找 Excel 文件
% ==========================================================

xlsxFiles = dir(fullfile(dataFolder, '*.xlsx'));


% 排除 Excel 临时文件
if ~isempty(xlsxFiles)

    fileNames = {xlsxFiles.name};

    isTemporary = startsWith(fileNames, '~$');

    xlsxFiles = xlsxFiles(~isTemporary);

end


if isempty(xlsxFiles)

    error(['当前文件夹中没有找到有效的 .xlsx 文件。', ...
        '请将 Excel 文件与本 m 文件放在同一个文件夹中。']);

end


if numel(xlsxFiles) > 1

    error(['当前文件夹中存在多个 Excel 文件。', ...
        '请只保留需要绘图的数据文件，', ...
        '或者在代码中手动指定 xlsxFile。']);

end


xlsxFile = fullfile( ...
    dataFolder, ...
    xlsxFiles(1).name);


% 手动指定文件时，可使用下面的写法：
% xlsxFile = fullfile(dataFolder, '你的数据文件.xlsx');


fprintf('正在读取数据文件：\n%s\n\n', xlsxFile);


%% =========================================================
% 3. 读取 Excel
% ==========================================================

sheetName = 1;


raw = readcell( ...
    xlsxFile, ...
    'Sheet', sheetName);


[nRows, nCols] = size(raw);


%% =========================================================
% 4. Excel 数据位置
% ==========================================================

paramRow     = 2;

strategyRow  = 3;

dataStartRow = 4;


if nRows < dataStartRow

    error('Excel 数据行数不足，请检查文件格式。');

end


%% =========================================================
% 5. 稳态计算及绘图设置
% ==========================================================

% 最后 10% 数据用于计算稳态比例
steadyFraction = 0.10;


% 稳态窗口至少包含的数据点数
minimumSteadyPoints = 100;


% 是否采用固定纵坐标范围
useManualYLim = true;


% 当前数据适合的纵坐标范围
manualYLim = [0.46, 0.54];


% 是否保存图片
saveFigure = false;


% 图片分辨率
exportResolution = 600;


%% =========================================================
% 6. 读取参数标签
% ==========================================================

headerStr = strings(1, nCols);


for colIdx = 1:nCols

    headerStr(colIdx) = ...
        safeCellToString(raw{paramRow, colIdx});

end


% 删除空格，方便识别 r=0.2 等标签
headerNormalized = erase(headerStr, " ");


%% =========================================================
% 7. 识别参数组起始列
% ==========================================================

paramCols = find( ...
    contains( ...
        headerNormalized, ...
        "r=", ...
        'IgnoreCase', true));


% 如果第 2 行没有明确的 r= 标签，
% 则根据第 3 行中的 A 或 t 识别参数组
if isempty(paramCols)

    strategyStr = strings(1, nCols);


    for colIdx = 1:nCols

        strategyStr(colIdx) = ...
            safeCellToString(raw{strategyRow, colIdx});

    end


    paramColsA = find( ...
        strcmpi(strategyStr, "A"));


    paramColsT = find( ...
        strcmpi(strategyStr, "t") | ...
        strcmpi(strategyStr, "time") | ...
        strcmp(strategyStr, "时间"));


    paramCols = sort( ...
        unique([paramColsA, paramColsT]));


    if isempty(paramCols)

        error(['未识别到参数组。请确认第 2 行包含 ', ...
            'r=0.2 等标签，第 3 行包含 A、B、C、D。']);

    end


    warning(['未识别到明确的 r= 参数标签，', ...
        '已根据第 3 行中的策略标签识别参数组。']);

end


numParams = numel(paramCols);


fprintf('共识别到 %d 组 r 参数。\n', numParams);


%% =========================================================
% 8. 提取 r 参数值
% ==========================================================

paramValues = nan(numParams, 1);


for paramIdx = 1:numParams

    labelText = char( ...
        headerNormalized(paramCols(paramIdx)));


    numberToken = regexp( ...
        labelText, ...
        '[-+]?\d*\.?\d+(?:[eE][-+]?\d+)?', ...
        'match');


    if ~isempty(numberToken)

        paramValues(paramIdx) = ...
            str2double(numberToken{1});

    else

        paramValues(paramIdx) = paramIdx;

    end

end


%% =========================================================
% 9. 读取各参数组的时间序列
% ==========================================================

% dataAll{k}.rho 的四列依次对应：
% A、B、C、D

dataAll = cell(numParams, 1);


for paramIdx = 1:numParams

    firstCol = paramCols(paramIdx);


    firstLabel = ...
        safeCellToString(raw{strategyRow, firstCol});


    % 判断是否包含时间列
    hasTimeColumn = ...
        strcmpi(firstLabel, "t") || ...
        strcmpi(firstLabel, "time") || ...
        strcmp(firstLabel, "时间");


    if hasTimeColumn

        timeCol = firstCol;

        strategyCols = ...
            firstCol + 1:firstCol + 4;

    else

        timeCol = [];

        strategyCols = ...
            firstCol:firstCol + 3;

    end


    if strategyCols(end) > nCols

        error(['第 %d 组参数后方不足 4 列，', ...
            '无法读取 A、B、C、D。'], paramIdx);

    end


    %% -----------------------------------------------------
    % 9.1 读取策略数据
    % ------------------------------------------------------

    strategyCellData = ...
        raw(dataStartRow:end, strategyCols);


    strategyDataAll = ...
        cellBlockToDouble(strategyCellData);


    % 只保留四类策略均有有效数值的行
    validRows = ...
        all(~isnan(strategyDataAll), 2);


    strategyData = ...
        strategyDataAll(validRows, :);


    if isempty(strategyData)

        error(['第 %d 组参数没有读取到', ...
            '有效的策略比例数据。'], paramIdx);

    end


    %% -----------------------------------------------------
    % 9.2 读取或生成时间序列
    % ------------------------------------------------------

    if hasTimeColumn

        timeCellData = ...
            raw(dataStartRow:end, timeCol);


        timeDataAll = ...
            cellBlockToDouble(timeCellData);


        timeData = ...
            timeDataAll(validRows);


        validTimeRows = ~isnan(timeData);


        timeData = ...
            timeData(validTimeRows);


        strategyData = ...
            strategyData(validTimeRows, :);


        if isempty(timeData)

            error(['第 %d 组参数的时间列', ...
                '没有读取到有效数据。'], paramIdx);

        end


    else

        timeData = ...
            (0:size(strategyData, 1)-1)';

    end


    dataAll{paramIdx}.t = timeData(:);

    dataAll{paramIdx}.rho = strategyData;

end


%% =========================================================
% 10. 按 r 从小到大排序
% ==========================================================

[paramValues, sortOrder] = sort(paramValues);

dataAll = dataAll(sortOrder);


%% =========================================================
% 11. 计算稳态比例
% ==========================================================

% 四列依次对应 A、B、C、D
steadyRho = nan(numParams, 4);

steadyWindowPoints = nan(numParams, 1);


for paramIdx = 1:numParams

    strategyData = ...
        dataAll{paramIdx}.rho;


    totalPoints = ...
        size(strategyData, 1);


    % 计算稳态窗口长度
    windowLength = ceil( ...
        steadyFraction * totalPoints);


    windowLength = max( ...
        windowLength, ...
        minimumSteadyPoints);


    windowLength = min( ...
        windowLength, ...
        totalPoints);


    startIndex = ...
        totalPoints - windowLength + 1;


    steadyData = ...
        strategyData(startIndex:end, :);


    steadyRho(paramIdx, :) = ...
        mean(steadyData, 1);


    steadyWindowPoints(paramIdx) = ...
        windowLength;

end


%% =========================================================
% 12. 输出稳态结果
% ==========================================================

resultTable = table( ...
    paramValues, ...
    steadyRho(:, 1), ...
    steadyRho(:, 2), ...
    steadyRho(:, 3), ...
    steadyRho(:, 4), ...
    steadyWindowPoints, ...
    'VariableNames', { ...
    'r', ...
    'rhoA_steady', ...
    'rhoB_steady', ...
    'rhoC_steady', ...
    'rhoD_steady', ...
    'windowPoints'});


fprintf('\n稳态比例采用每组数据最后 %.1f%% 的平均值。\n', ...
    steadyFraction * 100);


fprintf('\n不同 r 下的稳态比例：\n');


disp(resultTable);


%% =========================================================
% 13. 设置曲线颜色
% ==========================================================

% 保持原来的颜色不变

colorB = [0.0000, 0.4470, 0.7410];

colorC = [0.8500, 0.3250, 0.0980];


%% =========================================================
% 14. 创建普通折线图
% ==========================================================

% 原来为 16 × 10 cm
% 调整为 14 × 10 cm，使图形更紧凑

fig = figure( ...
    'Color', 'w', ...
    'Units', 'centimeters', ...
    'Position', [5,5,15,12], ...
    'Name', 'Steady-state proportions', ...
    'NumberTitle', 'off');


ax = axes( ...
    'Parent', fig);


hold(ax, 'on');


lineB = plot( ...
    ax, ...
    paramValues, ...
    steadyRho(:, 2), ...
    '-s', ...
    'LineWidth', 1.8, ...
    'MarkerSize', 7, ...
    'Color', colorB, ...
    'MarkerEdgeColor', colorB, ...
    'MarkerFaceColor', 'w');


lineC = plot( ...
    ax, ...
    paramValues, ...
    steadyRho(:, 3), ...
    '-^', ...
    'LineWidth', 1.8, ...
    'MarkerSize', 8, ...
    'Color', colorC, ...
    'MarkerEdgeColor', colorC, ...
    'MarkerFaceColor', 'w');


hold(ax, 'off');


%% =========================================================
% 15. 设置横坐标
% ==========================================================

xticks(ax, paramValues);


if numParams > 1

    xRange = ...
        max(paramValues) - min(paramValues);


    if xRange <= 0
        xRange = 1;
    end


    xMargin = 0.05 * xRange;


    xlim(ax, [ ...
        min(paramValues) - xMargin, ...
        max(paramValues) + xMargin]);

else

    xlim(ax, [ ...
        paramValues(1) - 0.5, ...
        paramValues(1) + 0.5]);

end


%% =========================================================
% 16. 设置纵坐标
% ==========================================================

visibleData = [ ...
    steadyRho(:, 2)
    steadyRho(:, 3)];


if useManualYLim

    % 检查固定范围是否包含所有数据
    if min(visibleData) >= manualYLim(1) && ...
            max(visibleData) <= manualYLim(2)

        ylim(ax, manualYLim);


        yticks(ax, ...
            manualYLim(1):0.02:manualYLim(2));

    else

        warning(['实际数据超出了 manualYLim，', ...
            '已自动计算纵坐标范围。']);


        useManualYLim = false;

    end

end


if ~useManualYLim

    dataMinimum = min(visibleData);

    dataMaximum = max(visibleData);


    dataRange = ...
        dataMaximum - dataMinimum;


    if dataRange < 1e-12

        yMargin = 0.01;

    else

        yMargin = 0.15 * dataRange;

    end


    yLower = max( ...
        0, ...
        dataMinimum - yMargin);


    yUpper = min( ...
        1, ...
        dataMaximum + yMargin);


    yLower = ...
        floor(yLower / 0.01) * 0.01;


    yUpper = ...
        ceil(yUpper / 0.01) * 0.01;


    ylim(ax, [yLower, yUpper]);

end


%% =========================================================
% 17. 坐标名称
% ==========================================================

% 横轴：
% 数学变量 r 使用 LaTeX
% 字号保持 16
% 不加粗

xlabel( ...
    ax, ...
    '$r$', ...
    'Interpreter', 'latex', ...
    'FontSize', 16, ...
    'FontWeight', 'normal');


% 纵轴：
% 普通英文使用 Times New Roman
% 字号保持 16
% 不加粗

ylabel( ...
    ax, ...
    'Steady-state strategy proportion', ...
    'Interpreter', 'tex', ...
    'FontName', 'Times New Roman', ...
    'FontSize', 16, ...
    'FontWeight', 'normal');


%% =========================================================
% 18. 图例
% ==========================================================

% 数学符号使用 LaTeX
% 字号保持 16
% 不加粗

lgd = legend( ...
    ax, ...
    [lineB, lineC], ...
    {'$\rho_B^{*}$', '$\rho_C^{*}$'}, ...
    'Interpreter', 'latex', ...
    'Location', 'best', ...
    'FontSize', 18, ...
    'FontWeight', 'normal', ...
    'Box', 'on');


% 防止后续操作自动改变图例
set( ...
    lgd, ...
    'AutoUpdate', 'off', ...
    'Visible', 'on');


%% =========================================================
% 19. 普通坐标轴格式
% ==========================================================

% 不显示背景网格
grid(ax, 'off');


% 显示四周坐标轴边框
box(ax, 'on');


% 坐标刻度使用 Times New Roman
% 字号保持 16
% 不加粗

set( ...
    ax, ...
    'FontName', 'Times New Roman', ...
    'FontSize', 18, ...
    'FontWeight', 'normal', ...
    'LineWidth', 1.4, ...
    'TickDir', 'in', ...
    'TickLength', [0.015, 0.015], ...
    'Layer', 'top');


%% =========================================================
% 20. 可选：保存图片
% ==========================================================

if saveFigure

    outputImage = fullfile( ...
        dataFolder, ...
        'steady_state_BC_vs_r.png');


    exportgraphics( ...
        fig, ...
        outputImage, ...
        'Resolution', exportResolution);


    fprintf('\n图片已保存至：\n%s\n', ...
        outputImage);

end


%% ========================================================================
% 辅助函数 1：
% 安全地将单元格内容转换为字符串
% ========================================================================

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


        str = strtrim(str);

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


%% ========================================================================
% 辅助函数 2：
% 将 cell 数据块转换为 double 矩阵
% ========================================================================

function numMat = cellBlockToDouble(cellBlock)

    [numRows, numCols] = size(cellBlock);


    numMat = nan(numRows, numCols);


    for rowIdx = 1:numRows

        for colIdx = 1:numCols

            value = cellBlock{rowIdx, colIdx};


            if isempty(value)

                numMat(rowIdx, colIdx) = NaN;


            elseif isnumeric(value)

                if isscalar(value)

                    numMat(rowIdx, colIdx) = ...
                        double(value);

                end


            elseif ischar(value)

                temporaryValue = ...
                    str2double(strtrim(value));


                if isscalar(temporaryValue) && ...
                        ~isnan(temporaryValue)

                    numMat(rowIdx, colIdx) = ...
                        temporaryValue;

                end


            elseif isstring(value)

                if ~all(ismissing(value(:)))

                    temporaryValue = ...
                        str2double(strtrim(value));


                    if isscalar(temporaryValue) && ...
                            ~isnan(temporaryValue)

                        numMat(rowIdx, colIdx) = ...
                            temporaryValue;

                    end

                end


            else

                try

                    temporaryValue = ...
                        str2double(string(value));


                    if isscalar(temporaryValue) && ...
                            ~isnan(temporaryValue)

                        numMat(rowIdx, colIdx) = ...
                            temporaryValue;

                    end


                catch

                    numMat(rowIdx, colIdx) = NaN;

                end

            end

        end

    end

end