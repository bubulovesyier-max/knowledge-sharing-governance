%% plot_hF_free_regime_steady_state.m
% 功能：
% 读取不同 h_F 下四种策略比例的时间序列，
% 使用最后 10% 时间步的平均值计算稳态比例，
% 绘制免费制下 A、B、C、D 四种策略的稳态比例折线图。
%
% Excel 数据结构：
% 第1行：模式名称，可有可无
% 第2行：参数标签，例如：
%        hF=0、hF=0.1、hF=0.25、hF=0.4、hF=0.5
% 第3行：策略标签 A、B、C、D
% 第4行及以后：策略比例时间序列
%
% 每组参数占4列，参数组之间允许有空列：
%
% hF=0                 hF=0.1
% A   B   C   D         A   B   C   D
%
% 稳态比例采用每组时间序列最后10%的平均值。
%
% 绘图格式：
% 1. 数学符号使用 LaTeX；
% 2. 普通英文和坐标刻度使用 Times New Roman；
% 3. 所有文字均不加粗；
% 4. 保留原有字号设置；
% 5. 保留淡紫色背景；
% 6. A、B、C、D 的颜色与全文其他图保持一致；
% 7. 不显示网格。

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
% 2. 查找 Excel 数据文件
% ==========================================================

xlsxFiles = dir(fullfile(dataFolder, '*.xlsx'));


% 排除 Excel 自动生成的临时文件
if ~isempty(xlsxFiles)

    fileNames = {xlsxFiles.name};

    temporaryFlag = startsWith(fileNames, '~$');

    xlsxFiles = xlsxFiles(~temporaryFlag);

end


if isempty(xlsxFiles)

    error(['当前文件夹中没有找到有效的 .xlsx 文件。', ...
        '请将 Excel 数据文件与本 m 文件放在同一个文件夹中。']);

end


if numel(xlsxFiles) > 1

    error(['当前文件夹中存在多个 Excel 文件。', ...
        '请只保留免费模式的数据文件，', ...
        '或者在代码中手动指定 xlsxFile。']);

end


% 自动读取唯一的 Excel 文件
xlsxFile = fullfile( ...
    dataFolder, ...
    xlsxFiles(1).name);


% 若需要手动指定文件名，可改为：
% xlsxFile = fullfile(dataFolder, '你的数据文件.xlsx');


fprintf('正在读取数据文件：\n%s\n\n', xlsxFile);


%% =========================================================
% 3. 读取 Excel 文件
% ==========================================================

sheetName = 'Sheet1';


raw = readcell( ...
    xlsxFile, ...
    'Sheet', sheetName);


[nRows, nCols] = size(raw);


%% =========================================================
% 4. Excel 数据位置设置
% ==========================================================

paramRow     = 2;   % hF 参数标签所在行

strategyRow  = 3;   % A、B、C、D 所在行

dataStartRow = 4;   % 时间序列开始行


if nRows < dataStartRow

    error(['Excel 数据行数不足。', ...
        '请检查参数行、策略行和数值数据是否完整。']);

end


%% =========================================================
% 5. 稳态计算与绘图设置
% ==========================================================

% 最后多少比例的数据用于计算稳态平均值
steadyFraction = 0.10;


% 稳态窗口至少包含的数据点数
minimumSteadyPoints = 100;


% 是否显示标题
showTitle = true;


% 是否自动保存图片
saveFigure = false;


% 是否保存稳态结果表
saveResultTable = false;


%% =========================================================
% 6. 读取参数标签
% ==========================================================

headerStr = strings(1, nCols);


for colIdx = 1:nCols

    headerStr(colIdx) = ...
        safeCellToString(raw{paramRow, colIdx});

end


% 将标签统一为小写，并删除空格、下划线和 LaTeX 符号
headerNormalized = normalizeHeader(headerStr);


%% =========================================================
% 7. 识别 hF 参数组起始列
% ==========================================================

paramCols = find( ...
    contains(headerNormalized, "hf="));


% 如果第2行未识别到 hF，则根据第3行中的 A 识别
if isempty(paramCols)

    strategyStr = strings(1, nCols);


    for colIdx = 1:nCols

        strategyStr(colIdx) = ...
            safeCellToString(raw{strategyRow, colIdx});

    end


    % 不带时间列时，每组从 A 开始
    paramCols = find( ...
        strcmpi(strategyStr, "A"));


    if isempty(paramCols)

        error(['未能识别 hF 参数组。请确认第2行包含 ', ...
            'hF=0、hF=0.1 等标签，', ...
            '且第3行包含 A、B、C、D。']);

    end


    warning(['未识别到明确的 hF 参数标签，', ...
        '已根据第3行中的 A 识别参数组。']);

end


numParams = numel(paramCols);


fprintf('共识别到 %d 组 hF 参数。\n', numParams);


%% =========================================================
% 8. 提取 hF 参数值
% ==========================================================

hFValues = nan(numParams, 1);


for paramIdx = 1:numParams

    labelText = char( ...
        headerNormalized(paramCols(paramIdx)));


    % 支持整数、小数、负数和科学计数法
    numberToken = regexp( ...
        labelText, ...
        '[-+]?\d*\.?\d+(?:[eE][-+]?\d+)?', ...
        'match');


    if ~isempty(numberToken)

        hFValues(paramIdx) = ...
            str2double(numberToken{1});

    else

        hFValues(paramIdx) = paramIdx;

    end

end


%% =========================================================
% 9. 读取各组 hF 下的时间序列
% ==========================================================

% dataAll{k}.rho：
% 第 k 个 hF 值对应的策略比例
%
% 四列依次为：
% A、B、C、D

dataAll = cell(numParams, 1);


for paramIdx = 1:numParams

    firstCol = paramCols(paramIdx);


    firstStrategyLabel = ...
        safeCellToString(raw{strategyRow, firstCol});


    % 判断该组是否含单独的时间列
    hasTimeColumn = ...
        strcmpi(firstStrategyLabel, "t") || ...
        strcmpi(firstStrategyLabel, "time") || ...
        strcmp(firstStrategyLabel, "时间");


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

        error(['第 %d 组参数后方不足4列，', ...
            '无法读取 A、B、C、D。'], paramIdx);

    end


    %% -----------------------------------------------------
    % 9.1 读取 A、B、C、D 策略比例
    % ------------------------------------------------------

    strategyCellData = ...
        raw(dataStartRow:end, strategyCols);


    strategyDataAll = ...
        cellBlockToDouble(strategyCellData);


    % 只保留 A、B、C、D 均为有效数值的行
    validRows = ...
        all(~isnan(strategyDataAll), 2);


    strategyData = ...
        strategyDataAll(validRows, :);


    if isempty(strategyData)

        error(['第 %d 组 hF 参数没有读取到', ...
            '有效的策略比例数据。'], paramIdx);

    end


    %% -----------------------------------------------------
    % 9.2 若有时间列，删除时间无效的行
    % ------------------------------------------------------

    if hasTimeColumn

        timeCellData = ...
            raw(dataStartRow:end, timeCol);


        timeDataAll = ...
            cellBlockToDouble(timeCellData);


        timeData = ...
            timeDataAll(validRows);


        validTimeRows = ...
            ~isnan(timeData);


        strategyData = ...
            strategyData(validTimeRows, :);

    end


    dataAll{paramIdx}.rho = ...
        strategyData;

end


%% =========================================================
% 10. 按 hF 从小到大排序
% ==========================================================

[hFValues, sortOrder] = sort(hFValues);


dataAll = dataAll(sortOrder);


%% =========================================================
% 11. 计算稳态比例
% ==========================================================

% steadyRho：
% 行对应不同 hF
% 四列分别对应 A、B、C、D

steadyRho = nan(numParams, 4);


% 记录每组实际采用的稳态窗口长度
steadyWindowPoints = nan(numParams, 1);


% 记录稳态窗口中的标准差
steadyStd = nan(numParams, 4);


for paramIdx = 1:numParams

    strategyData = ...
        dataAll{paramIdx}.rho;


    totalPoints = ...
        size(strategyData, 1);


    % 根据最后10%确定窗口长度
    windowLength = ceil( ...
        steadyFraction * totalPoints);


    % 保证窗口至少包含指定数量的数据点
    windowLength = max( ...
        windowLength, ...
        minimumSteadyPoints);


    % 窗口长度不能超过总数据长度
    windowLength = min( ...
        windowLength, ...
        totalPoints);


    startIndex = ...
        totalPoints - windowLength + 1;


    steadyData = ...
        strategyData(startIndex:end, :);


    % 稳态均值
    steadyRho(paramIdx, :) = ...
        mean(steadyData, 1);


    % 稳态窗口内标准差
    steadyStd(paramIdx, :) = ...
        std(steadyData, 0, 1);


    steadyWindowPoints(paramIdx) = ...
        windowLength;

end


%% =========================================================
% 12. 检查四类策略稳态比例之和
% ==========================================================

steadySum = sum(steadyRho, 2);


fprintf('\n各 hF 下四种策略稳态比例之和：\n');


for paramIdx = 1:numParams

    fprintf('hF = %.4g，比例之和 = %.8f\n', ...
        hFValues(paramIdx), ...
        steadySum(paramIdx));

end


%% =========================================================
% 13. 输出稳态结果表
% ==========================================================

resultTable = table( ...
    hFValues, ...
    steadyRho(:, 1), ...
    steadyRho(:, 2), ...
    steadyRho(:, 3), ...
    steadyRho(:, 4), ...
    steadyStd(:, 1), ...
    steadyStd(:, 2), ...
    steadyStd(:, 3), ...
    steadyStd(:, 4), ...
    steadyWindowPoints, ...
    'VariableNames', { ...
        'hF', ...
        'rhoA_steady', ...
        'rhoB_steady', ...
        'rhoC_steady', ...
        'rhoD_steady', ...
        'rhoA_std', ...
        'rhoB_std', ...
        'rhoC_std', ...
        'rhoD_std', ...
        'windowPoints'});


fprintf('\n稳态比例采用每组最后 %.1f%% 数据的平均值。\n', ...
    steadyFraction * 100);


fprintf('\n免费模式下不同 hF 对应的稳态比例：\n');


disp(resultTable);


%% =========================================================
% 14. 设置四种策略的统一颜色和标记
% ==========================================================

% 与前文其他策略图保持一致：
% A：紫色
% B：橙红色
% C：蓝色
% D：绿色

strategyColors = [
    0.4940, 0.1840, 0.5560;   % A
    0.8500, 0.3250, 0.0980;   % B
    0.0000, 0.4470, 0.7410;   % C
    0.4660, 0.6740, 0.1880    % D
];


strategyMarkers = {
    'o'
    's'
    '^'
    'd'
};


strategyLegend = {
    '$\rho_A^{*}$'
    '$\rho_B^{*}$'
    '$\rho_C^{*}$'
    '$\rho_D^{*}$'
};


%% =========================================================
% 15. 创建免费制稳态比例图
% ==========================================================

fig = figure( ...
    'Color', 'w', ...
    'Units', 'centimeters', ...
    'Position', [5, 5, 18, 14], ...
    'Name', 'Free regime steady-state proportions', ...
    'NumberTitle', 'off');


ax = axes( ...
    'Parent', fig, ...
    'Position', [0.14, 0.15, 0.80, 0.78]);


%% =========================================================
% 16. 保留原有淡紫色背景
% ==========================================================

set( ...
    ax, ...
    'Color', [0.96, 0.95, 1]);


hold(ax, 'on');


%% =========================================================
% 17. 绘制四种策略
% ==========================================================

lineHandles = gobjects(4, 1);


for strategyIdx = 1:4

    lineHandles(strategyIdx) = plot( ...
        ax, ...
        hFValues, ...
        steadyRho(:, strategyIdx), ...
        '-', ...
        'LineWidth', 1.8, ...
        'Marker', strategyMarkers{strategyIdx}, ...
        'MarkerSize', 7, ...
        'MarkerFaceColor', 'w', ...
        'MarkerEdgeColor', strategyColors(strategyIdx, :), ...
        'Color', strategyColors(strategyIdx, :));

end


hold(ax, 'off');


%% =========================================================
% 18. 坐标范围与刻度
% ==========================================================

ylim(ax, [-0.02, 1.02]);


yticks(ax, 0:0.2:1);


xticks(ax, hFValues);


xtickangle(ax, 0);


% 横坐标两端保留少量边距
if numParams > 1

    xRange = ...
        max(hFValues) - min(hFValues);


    if xRange <= 0

        xRange = 1;

    end


    xMargin = ...
        0.05 * xRange;


    xlim(ax, [ ...
        min(hFValues) - xMargin, ...
        max(hFValues) + xMargin]);

else

    xlim(ax, [ ...
        hFValues(1) - 0.5, ...
        hFValues(1) + 0.5]);

end


%% =========================================================
% 19. 坐标轴标签
% ==========================================================

% 横轴数学变量使用 LaTeX
% 保持原字号 18
% 不加粗

xlabel( ...
    ax, ...
    '$h_f$', ...
    'Interpreter', 'latex', ...
    'FontSize', 18, ...
    'FontWeight', 'normal');


% 纵轴普通英文使用 Times New Roman
% 保持原字号 18
% 不加粗

ylabel( ...
    ax, ...
    'Steady-state strategy proportion', ...
    'Interpreter', 'tex', ...
    'FontName', 'Times New Roman', ...
    'FontSize', 18, ...
    'FontWeight', 'normal');


%% =========================================================
% 20. 标题
% ==========================================================

if showTitle

    title( ...
        ax, ...
        'Free regime', ...
        'Interpreter', 'tex', ...
        'FontName', 'Times New Roman', ...
        'FontSize', 18, ...
        'FontWeight', 'normal');

end


%% =========================================================
% 21. 图例
% ==========================================================

% 数学符号使用 LaTeX
% 保持原字号 15
% 不加粗

legendHandle = legend( ...
    ax, ...
    lineHandles, ...
    strategyLegend, ...
    'Interpreter', 'latex', ...
    'Location', 'best', ...
    'FontSize', 18, ...
    'FontWeight', 'normal', ...
    'Box', 'on');


set( ...
    legendHandle, ...
    'AutoUpdate', 'off', ...
    'Visible', 'on');


%% =========================================================
% 22. 坐标轴统一格式
% ==========================================================

% 不显示网格
grid(ax, 'off');


% 显示四周边框
box(ax, 'on');


% 坐标刻度使用 Times New Roman
% 保持原字号 16
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
% 23. 调整边距
% ==========================================================

drawnow;


set( ...
    ax, ...
    'LooseInset', ...
    max(get(ax, 'TightInset'), 0.02));


%% =========================================================
% 24. 可选：保存图片
% ==========================================================

if saveFigure

    outputFigure = fullfile( ...
        dataFolder, ...
        'free_regime_steady_state_vs_hF.pdf');


    exportgraphics( ...
        fig, ...
        outputFigure, ...
        'ContentType', 'vector');


    fprintf('\n图片已保存至：\n%s\n', ...
        outputFigure);

end


%% =========================================================
% 25. 可选：保存稳态结果表
% ==========================================================

if saveResultTable

    outputTable = fullfile( ...
        dataFolder, ...
        'free_regime_steady_state_vs_hF.xlsx');


    writetable( ...
        resultTable, ...
        outputTable);


    fprintf('\n稳态结果表已保存至：\n%s\n', ...
        outputTable);

end


%% ========================================================================
% 辅助函数1：
% 统一参数标签格式
% ========================================================================

function normalizedText = normalizeHeader(inputText)

    normalizedText = ...
        lower(string(inputText));


    normalizedText = ...
        erase(normalizedText, " ");

    normalizedText = ...
        erase(normalizedText, "_");

    normalizedText = ...
        erase(normalizedText, "$");

    normalizedText = ...
        erase(normalizedText, "{");

    normalizedText = ...
        erase(normalizedText, "}");

    normalizedText = ...
        erase(normalizedText, "\");


    normalizedText = ...
        strtrim(normalizedText);

end


%% ========================================================================
% 辅助函数2：
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
% 辅助函数3：
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

                else

                    numMat(rowIdx, colIdx) = NaN;

                end


            elseif ischar(value)

                temporaryValue = ...
                    str2double(strtrim(value));


                if isscalar(temporaryValue) && ...
                        ~isnan(temporaryValue)

                    numMat(rowIdx, colIdx) = ...
                        temporaryValue;

                else

                    numMat(rowIdx, colIdx) = NaN;

                end


            elseif isstring(value)

                if all(ismissing(value(:)))

                    numMat(rowIdx, colIdx) = NaN;

                else

                    temporaryValue = ...
                        str2double(strtrim(value));


                    if isscalar(temporaryValue) && ...
                            ~isnan(temporaryValue)

                        numMat(rowIdx, colIdx) = ...
                            temporaryValue;

                    else

                        numMat(rowIdx, colIdx) = NaN;

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

                    else

                        numMat(rowIdx, colIdx) = NaN;

                    end


                catch

                    numMat(rowIdx, colIdx) = NaN;

                end

            end

        end

    end

end