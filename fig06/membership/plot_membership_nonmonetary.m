%% plot_hM_membership_steady_state.m
% 功能：
% 读取会员制下不同 h_M 对应的策略比例时间序列，
% 使用最后10%时间步的平均值计算稳态比例，
% 绘制策略 A、B、C、D 随 h_M 变化的稳态比例折线图。
%
% Excel数据结构：
% 第1行：模式名称
% 第2行：hM=0、hM=0.25、hM=0.5、hM=0.75、hM=1
% 第3行：A、B、C、D
% 第4行及以后：策略比例时间序列
%
% 每组参数占4列，参数组之间允许有空列：
%
% hM=0                    hM=0.25
% A   B   C   D           A   B   C   D
%
% 绘图格式：
% 1. 数学符号使用 LaTeX；
% 2. 普通英文和坐标刻度使用 Times New Roman；
% 3. 所有文字均不加粗；
% 4. 保留原有字号设置；
% 5. 保留会员制原有淡黄色背景；
% 6. A、B、C、D 的颜色与全文其他图保持一致；
% 7. 不显示背景网格。

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


% 排除 Excel 自动生成的临时文件
if ~isempty(xlsxFiles)

    fileNames = {xlsxFiles.name};

    temporaryFlag = startsWith(fileNames, '~$');

    xlsxFiles = xlsxFiles(~temporaryFlag);

end


if isempty(xlsxFiles)

    error(['当前文件夹中没有找到有效的 .xlsx 文件。', ...
        '请将会员制 Excel 数据文件与本 m 文件放在同一个文件夹中。']);

end


if numel(xlsxFiles) > 1

    error(['当前文件夹中存在多个 Excel 文件。', ...
        '请只保留需要绘图的会员制数据文件，', ...
        '或者在代码中手动指定 xlsxFile。']);

end


% 自动读取当前文件夹中的唯一 Excel 文件
xlsxFile = fullfile( ...
    dataFolder, ...
    xlsxFiles(1).name);


% 若需要手动指定文件名，可使用：
% xlsxFile = fullfile(dataFolder, '你的数据文件.xlsx');


fprintf('正在读取数据文件：\n%s\n\n', xlsxFile);


%% =========================================================
% 3. 读取 Excel 数据
% ==========================================================

sheetName = 'Sheet1';


raw = readcell( ...
    xlsxFile, ...
    'Sheet', sheetName);


[nRows, nCols] = size(raw);


%% =========================================================
% 4. Excel 数据位置
% ==========================================================

paramRow     = 2;   % hM 参数标签所在行

strategyRow  = 3;   % A、B、C、D 所在行

dataStartRow = 4;   % 时间序列起始行


if nRows < dataStartRow

    error(['Excel 数据行数不足。', ...
        '请检查参数标签、策略名称和时间序列数据是否完整。']);

end


%% =========================================================
% 5. 稳态计算和绘图设置
% ==========================================================

% 使用最后多少比例的数据计算稳态平均值
steadyFraction = 0.10;


% 稳态窗口至少包含的数据点数
minimumSteadyPoints = 100;


% 是否显示图标题
showTitle = true;


% 图标题
panelTitle = 'Membership regime';


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


% 统一参数标签格式
headerNormalized = ...
    normalizeHeader(headerStr);


%% =========================================================
% 7. 识别 hM 参数组的起始列
% ==========================================================

paramCols = find( ...
    contains(headerNormalized, "hm="));


% 如果未识别到 hM 参数标签，
% 则根据第3行中的策略 A 识别每组起始列
if isempty(paramCols)

    strategyStr = strings(1, nCols);


    for colIdx = 1:nCols

        strategyStr(colIdx) = ...
            safeCellToString(raw{strategyRow, colIdx});

    end


    paramCols = find( ...
        strcmpi(strategyStr, "A"));


    if isempty(paramCols)

        error(['未能识别 hM 参数组。请确认第2行包含 ', ...
            'hM=0、hM=0.25 等标签，', ...
            '且第3行包含 A、B、C、D。']);

    end


    warning(['未识别到明确的 hM 参数标签，', ...
        '已根据第3行中的策略 A 识别参数组。']);

end


numParams = numel(paramCols);


fprintf('共识别到 %d 组 hM 参数。\n', numParams);


%% =========================================================
% 8. 提取 hM 参数值
% ==========================================================

hMValues = nan(numParams, 1);


for paramIdx = 1:numParams

    labelText = char( ...
        headerNormalized(paramCols(paramIdx)));


    % 支持整数、小数、负数和科学计数法
    numberToken = regexp( ...
        labelText, ...
        '[-+]?\d*\.?\d+(?:[eE][-+]?\d+)?', ...
        'match');


    if ~isempty(numberToken)

        hMValues(paramIdx) = ...
            str2double(numberToken{1});

    else

        hMValues(paramIdx) = paramIdx;

    end

end


%% =========================================================
% 9. 读取各组 hM 下的策略时间序列
% ==========================================================

% dataAll{k}.rho 的四列依次为：
% A、B、C、D

dataAll = cell(numParams, 1);


for paramIdx = 1:numParams

    firstCol = paramCols(paramIdx);


    firstStrategyLabel = ...
        safeCellToString(raw{strategyRow, firstCol});


    % 判断每组数据是否含有单独的时间列
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
            '无法读取 A、B、C、D。'], ...
            paramIdx);

    end


    %% -----------------------------------------------------
    % 9.1 读取 A、B、C、D 数据
    % ------------------------------------------------------

    strategyCellData = ...
        raw(dataStartRow:end, strategyCols);


    strategyDataAll = ...
        cellBlockToDouble(strategyCellData);


    % 仅保留四种策略均为有效数值的行
    validRows = ...
        all(~isnan(strategyDataAll), 2);


    strategyData = ...
        strategyDataAll(validRows, :);


    if isempty(strategyData)

        error(['第 %d 组 hM 参数没有读取到', ...
            '有效的策略比例数据。'], ...
            paramIdx);

    end


    %% -----------------------------------------------------
    % 9.2 若存在时间列，删除时间无效的行
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
% 10. 按 hM 从小到大排序
% ==========================================================

[hMValues, sortOrder] = ...
    sort(hMValues);


dataAll = ...
    dataAll(sortOrder);


%% =========================================================
% 11. 计算稳态比例
% ==========================================================

% steadyRho：
% 行对应不同 hM
% 列依次对应 A、B、C、D

steadyRho = nan(numParams, 4);


% 稳态窗口内标准差
steadyStd = nan(numParams, 4);


% 实际采用的稳态窗口点数
steadyWindowPoints = nan(numParams, 1);


for paramIdx = 1:numParams

    strategyData = ...
        dataAll{paramIdx}.rho;


    totalPoints = ...
        size(strategyData, 1);


    % 最后10%的数据点数量
    windowLength = ceil( ...
        steadyFraction * totalPoints);


    % 至少使用指定数量的数据点
    windowLength = max( ...
        windowLength, ...
        minimumSteadyPoints);


    % 窗口不能超过数据总长度
    windowLength = min( ...
        windowLength, ...
        totalPoints);


    startIndex = ...
        totalPoints - windowLength + 1;


    steadyData = ...
        strategyData(startIndex:end, :);


    % 稳态平均比例
    steadyRho(paramIdx, :) = ...
        mean(steadyData, 1);


    % 稳态窗口内标准差
    steadyStd(paramIdx, :) = ...
        std(steadyData, 0, 1);


    steadyWindowPoints(paramIdx) = ...
        windowLength;

end


%% =========================================================
% 12. 检查四种策略比例之和
% ==========================================================

steadySum = ...
    sum(steadyRho, 2);


fprintf('\n各 hM 下四种策略稳态比例之和：\n');


for paramIdx = 1:numParams

    fprintf('hM = %.4g，比例之和 = %.8f\n', ...
        hMValues(paramIdx), ...
        steadySum(paramIdx));

end


%% =========================================================
% 13. 输出稳态结果表
% ==========================================================

resultTable = table( ...
    hMValues, ...
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
        'hM', ...
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


fprintf('\n会员制下不同 hM 对应的稳态比例：\n');


disp(resultTable);


%% =========================================================
% 14. 设置四种策略的统一颜色和标记
% ==========================================================

% 与免费制、分成制以及全文其他策略图保持一致：
%
% A：紫色
% B：橙红色
% C：蓝色
% D：绿色

strategyColors = [
    0.4940, 0.1840, 0.5560;   % A：紫色
    0.8500, 0.3250, 0.0980;   % B：橙红色
    0.0000, 0.4470, 0.7410;   % C：蓝色
    0.4660, 0.6740, 0.1880    % D：绿色
];


strategyMarkers = {
    'o'     % A：圆形
    's'     % B：方形
    '^'     % C：三角形
    'd'     % D：菱形
};


strategyLegend = {
    '$\rho_A^{*}$'
    '$\rho_B^{*}$'
    '$\rho_C^{*}$'
    '$\rho_D^{*}$'
};


%% =========================================================
% 15. 创建会员制稳态比例图
% ==========================================================

fig = figure( ...
    'Color', 'w', ...
    'Units', 'centimeters', ...
    'Position', [5, 5, 18, 14], ...
    'Name', 'Membership regime steady-state proportions', ...
    'NumberTitle', 'off');


ax = axes( ...
    'Parent', fig, ...
    'Position', [0.14, 0.15, 0.80, 0.78]);


%% =========================================================
% 16. 保留原有淡黄色背景
% ==========================================================

set( ...
    ax, ...
    'Color', [1, 0.97, 0.90]);


hold(ax, 'on');


%% =========================================================
% 17. 绘制四种策略
% ==========================================================

lineHandles = gobjects(4, 1);


for strategyIdx = 1:4

    lineHandles(strategyIdx) = plot( ...
        ax, ...
        hMValues, ...
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


xticks(ax, hMValues);


xtickangle(ax, 0);


% 横坐标两端保留少量边距
if numParams > 1

    xRange = ...
        max(hMValues) - min(hMValues);


    if xRange <= 0

        xRange = 1;

    end


    xMargin = ...
        0.05 * xRange;


    xlim(ax, [ ...
        min(hMValues) - xMargin, ...
        max(hMValues) + xMargin]);

else

    xlim(ax, [ ...
        hMValues(1) - 0.5, ...
        hMValues(1) + 0.5]);

end


%% =========================================================
% 19. 坐标轴标签
% ==========================================================

% 横轴：
% 数学变量使用 LaTeX
% 保持原字号 18
% 不加粗

xlabel( ...
    ax, ...
    '$h_m$', ...
    'Interpreter', 'latex', ...
    'FontSize', 18, ...
    'FontWeight', 'normal');


% 纵轴：
% 普通英文使用 Times New Roman
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
        panelTitle, ...
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


% 防止后续操作自动修改图例
set( ...
    legendHandle, ...
    'AutoUpdate', 'off', ...
    'Visible', 'on');


%% =========================================================
% 22. 坐标轴统一格式
% ==========================================================

% 显示四周边框
box(ax, 'on');


% 不显示网格
grid(ax, 'off');


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
        'membership_steady_state_vs_hM.pdf');


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
        'membership_steady_state_vs_hM.xlsx');


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

        str = ...
            string(strtrim(value));

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

        missingFlag = ...
            ismissing(value);


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

    [numRows, numCols] = ...
        size(cellBlock);


    numMat = ...
        nan(numRows, numCols);


    for rowIdx = 1:numRows

        for colIdx = 1:numCols

            value = ...
                cellBlock{rowIdx, colIdx};


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