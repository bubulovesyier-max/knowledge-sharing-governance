%% fig3.m
% 功能：
% 读取与本 m 文件位于同一文件夹中的 Excel 数据，
% 将四种策略的时间演化过程绘制成四个独立的 Figure。
%
% 四个独立图分别为：
% Figure 1：rho_A(t)
% Figure 2：rho_B(t)
% Figure 3：rho_C(t)
% Figure 4：rho_D(t)
%
% 每张图中的不同曲线表示不同的 theta 参数值。
%
% 统一绘图格式：
% 1. 数学符号统一使用 LaTeX；
% 2. 所有文字均不加粗；
% 3. 坐标刻度及普通文字使用 Times New Roman；
% 4. 坐标轴标题字号为 18；
% 5. 坐标刻度字号为 16；
% 6. 图例字号为 16；
% 7. 保持原有曲线颜色不变；
% 8. PDF 使用矢量格式导出。

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

% 排除 Excel 自动生成的临时文件，例如 ~$data.xlsx
if ~isempty(xlsxFiles)

    fileNames = {xlsxFiles.name};

    temporaryFlag = startsWith(fileNames, '~$');

    xlsxFiles = xlsxFiles(~temporaryFlag);

end


if isempty(xlsxFiles)

    error(['当前文件夹中没有找到有效的 .xlsx 文件。', ...
        '请将 Excel 数据文件和 fig3.m 放在同一个文件夹中。']);

end


% 默认读取当前文件夹中的第一个 Excel 文件
xlsxFile = fullfile(dataFolder, xlsxFiles(1).name);


% 如果存在多个 Excel 文件，提醒用户
if numel(xlsxFiles) > 1

    warning(['当前文件夹中检测到多个 Excel 文件，', ...
        '程序将读取第一个文件：%s'], ...
        xlsxFiles(1).name);

end


fprintf('正在读取数据文件：\n%s\n\n', xlsxFile);


%% =========================================================
% 3. 读取 Excel 数据
% ==========================================================

sheetName = 1;

raw = readcell( ...
    xlsxFile, ...
    'Sheet', sheetName);

[nRows, nCols] = size(raw);


%% =========================================================
% 4. 设置 Excel 中各部分所在行
% ==========================================================

paramRow     = 2;    % 参数标签所在行
strategyRow  = 3;    % A、B、C、D 所在行
dataStartRow = 4;    % 数据开始行


if nRows < dataStartRow

    error(['Excel 数据行数不足。', ...
        '请检查参数行、策略行和数据行是否完整。']);

end


%% =========================================================
% 5. 读取参数标签
% ==========================================================

headerStr = strings(1, nCols);


for colIdx = 1:nCols

    headerStr(colIdx) = ...
        safeCellToString(raw{paramRow, colIdx});

end


% 去掉参数标签中的空格
headerNormalized = erase(headerStr, " ");


%% =========================================================
% 6. 识别参数组起始列
% ==========================================================

% 优先识别 theta 或希腊字母 θ
paramCols = find( ...
    contains( ...
        headerNormalized, ...
        "theta=", ...
        'IgnoreCase', true) | ...
    contains( ...
        headerNormalized, ...
        "θ=", ...
        'IgnoreCase', true));


% 如果没有识别到 theta，则兼容 p 或 s
if isempty(paramCols)

    paramCols = find( ...
        contains( ...
            headerNormalized, ...
            "p=", ...
            'IgnoreCase', true) | ...
        contains( ...
            headerNormalized, ...
            "s=", ...
            'IgnoreCase', true));

end


% 如果第 2 行没有明确参数标签，
% 则根据第 3 行中的 A 或 t 识别参数组
if isempty(paramCols)

    strategyStr = strings(1, nCols);


    for colIdx = 1:nCols

        strategyStr(colIdx) = ...
            safeCellToString(raw{strategyRow, colIdx});

    end


    % 不带时间列
    paramColsA = find(strcmpi(strategyStr, "A"));


    % 带时间列
    paramColsT = find( ...
        strcmpi(strategyStr, "t") | ...
        strcmpi(strategyStr, "time") | ...
        strcmp(strategyStr, "时间"));


    paramCols = sort(unique([paramColsA, paramColsT]));


    if isempty(paramCols)

        error(['未能识别参数组。请确认第 2 行包含 ', ...
            'theta=0.2 或 θ=0.2 等参数标签，', ...
            '且第 3 行包含 A、B、C、D。']);

    end


    warning(['未识别到明确参数标签，', ...
        '已根据第 3 行的策略标签识别参数组。']);

end


numParams = numel(paramCols);

fprintf('共识别到 %d 组参数。\n', numParams);


%% =========================================================
% 7. 判断参数类型
% ==========================================================

if any( ...
        contains( ...
            headerNormalized(paramCols), ...
            "theta=", ...
            'IgnoreCase', true) | ...
        contains( ...
            headerNormalized(paramCols), ...
            "θ=", ...
            'IgnoreCase', true))

    paramSymbol = 'theta';


elseif any( ...
        contains( ...
            headerNormalized(paramCols), ...
            "p=", ...
            'IgnoreCase', true))

    paramSymbol = 'p';


elseif any( ...
        contains( ...
            headerNormalized(paramCols), ...
            "s=", ...
            'IgnoreCase', true))

    paramSymbol = 's';


else

    paramSymbol = 'parameter';

end


%% =========================================================
% 8. 提取各参数数值
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
% 9. 读取每组参数下的时间序列数据
% ==========================================================

dataAll = cell(numParams, 1);


for paramIdx = 1:numParams

    firstCol = paramCols(paramIdx);


    firstStrategyLabel = ...
        safeCellToString(raw{strategyRow, firstCol});


    % 判断是否存在时间列
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

        error(['第 %d 组参数后方不足 4 列，', ...
            '无法读取 A、B、C、D。'], ...
            paramIdx);

    end


    %% -----------------------------------------------------
    % 读取 A、B、C、D
    % ------------------------------------------------------

    strategyCellData = ...
        raw(dataStartRow:end, strategyCols);


    strategyDataAll = ...
        cellBlockToDouble(strategyCellData);


    % 只保留四种策略均为有效数值的行
    validStrategyRows = ...
        all(~isnan(strategyDataAll), 2);


    strategyData = ...
        strategyDataAll(validStrategyRows, :);


    if isempty(strategyData)

        error(['第 %d 组参数没有读取到有效的 ', ...
            'A、B、C、D 策略数据。'], ...
            paramIdx);

    end


    %% -----------------------------------------------------
    % 读取时间
    % ------------------------------------------------------

    if hasTimeColumn

        timeCellData = ...
            raw(dataStartRow:end, timeCol);


        timeDataAll = ...
            cellBlockToDouble(timeCellData);


        timeData = ...
            timeDataAll(validStrategyRows);


        validTimeRows = ~isnan(timeData);


        timeData = ...
            timeData(validTimeRows);


        strategyData = ...
            strategyData(validTimeRows, :);


        if isempty(timeData)

            error(['第 %d 组参数的时间列中', ...
                '没有读取到有效数值。'], ...
                paramIdx);

        end


    else

        % 若没有时间列，则默认从 t=0 开始
        timeData = ...
            (0:size(strategyData, 1)-1)';

    end


    timeData = timeData(:);


    dataAll{paramIdx}.t = timeData;

    dataAll{paramIdx}.rho = strategyData;

end


%% =========================================================
% 10. 按参数值从小到大排序
% ==========================================================

[paramValues, sortOrder] = sort(paramValues);

dataAll = dataAll(sortOrder);


%% =========================================================
% 11. 绘图参数设置
% ==========================================================

% 每隔多少个时间步绘制一次
plotEvery = 10;


% 曲线宽度
lineWidth = 2;


% 是否自动导出 PDF
savePDF = true;


% 是否统一四张图的横坐标范围
useUnifiedTimeRange = true;


%% =========================================================
% 12. 设置曲线颜色
% ==========================================================

% 注意：
% 以下颜色与原代码完全一致，不进行修改

baseColors = [
    0.4941, 0.1843, 0.5569
    0.9294, 0.4902, 0.1922
    0.0000, 0.5000, 0.5000
    0.1176, 0.3137, 0.5961
];


if numParams == size(baseColors, 1)

    colors = baseColors;


elseif numParams == 1

    colors = baseColors(1, :);


else

    originalPosition = ...
        linspace(0, 1, size(baseColors, 1));


    newPosition = ...
        linspace(0, 1, numParams);


    colors = interp1( ...
        originalPosition, ...
        baseColors, ...
        newPosition, ...
        'linear');

end


%% =========================================================
% 13. 设置纵坐标数学符号
% ==========================================================

% 所有公式均使用 LaTeX
% 不加粗

strategyYLabels = {
    '$\rho_A$'
    '$\rho_B$'
    '$\rho_C$'
    '$\rho_D$'
};


figureNames = {
    'rho_A_time_evolution'
    'rho_B_time_evolution'
    'rho_C_time_evolution'
    'rho_D_time_evolution'
};


%% =========================================================
% 14. 生成图例
% ==========================================================

legendLabels = cell(numParams, 1);


for paramIdx = 1:numParams

    if strcmp(paramSymbol, 'theta')

        legendLabels{paramIdx} = sprintf( ...
            '$\\theta=%.4g$', ...
            paramValues(paramIdx));


    elseif strcmp(paramSymbol, 'p')

        legendLabels{paramIdx} = sprintf( ...
            '$p=%.4g$', ...
            paramValues(paramIdx));


    elseif strcmp(paramSymbol, 's')

        legendLabels{paramIdx} = sprintf( ...
            '$s=%.4g$', ...
            paramValues(paramIdx));


    else

        legendLabels{paramIdx} = sprintf( ...
            'Parameter = %.4g', ...
            paramValues(paramIdx));

    end

end


%% =========================================================
% 15. 计算统一横坐标范围
% ==========================================================

minimumTime = inf;

maximumTime = -inf;


for paramIdx = 1:numParams

    currentTime = dataAll{paramIdx}.t;


    minimumTime = min( ...
        minimumTime, ...
        min(currentTime));


    maximumTime = max( ...
        maximumTime, ...
        max(currentTime));

end


if ~isfinite(minimumTime) || ~isfinite(maximumTime)

    error('没有读取到有效的时间数据。');

end


%% =========================================================
% 16. 设置四个独立图窗的位置
% ==========================================================

figurePositions = [
     2, 13, 14, 10
    17, 13, 14, 10
     2,  2, 14, 10
    17,  2, 14, 10
];


%% =========================================================
% 17. 绘制四个独立 Figure
% ==========================================================

figureHandles = gobjects(4, 1);

legendHandles = gobjects(4, 1);


for strategyIdx = 1:4


    %% -----------------------------------------------------
    % 创建 Figure
    % ------------------------------------------------------

    figureHandles(strategyIdx) = figure( ...
        'Color', 'w', ...
        'Units', 'centimeters', ...
        'Position', figurePositions(strategyIdx, :), ...
        'Name', figureNames{strategyIdx}, ...
        'NumberTitle', 'off', ...
        'Renderer', 'painters');


    set( ...
        figureHandles(strategyIdx), ...
        'PaperPositionMode', 'auto');


    ax = axes( ...
        'Parent', figureHandles(strategyIdx));


    hold(ax, 'on');


    lineHandles = gobjects(numParams, 1);


    %% -----------------------------------------------------
    % 绘制不同参数下的曲线
    % ------------------------------------------------------

    for paramIdx = 1:numParams

        currentTime = ...
            dataAll{paramIdx}.t;


        currentRho = ...
            dataAll{paramIdx}.rho(:, strategyIdx);


        dataLength = min( ...
            numel(currentTime), ...
            numel(currentRho));


        currentTime = ...
            currentTime(1:dataLength);


        currentRho = ...
            currentRho(1:dataLength);


        plotIndex = ...
            1:plotEvery:dataLength;


        % 确保最后一个数据点被绘制
        if plotIndex(end) ~= dataLength

            plotIndex = [
                plotIndex, ...
                dataLength
            ];

        end


        lineHandles(paramIdx) = plot( ...
            ax, ...
            currentTime(plotIndex), ...
            currentRho(plotIndex), ...
            'LineStyle', '-', ...
            'LineWidth', lineWidth, ...
            'Color', colors(paramIdx, :));

    end


    hold(ax, 'off');


    %% -----------------------------------------------------
    % 坐标轴设置
    % ------------------------------------------------------

    grid(ax, 'off');

    box(ax, 'on');


    % 策略比例范围
    ylim(ax, [0, 1]);


    % 纵轴刻度：
    % 0, 0.2, 0.4, 0.6, 0.8, 1
    yticks(ax, 0:0.2:1);


    % 横轴范围
    if useUnifiedTimeRange

        xlim(ax, [
            minimumTime, ...
            maximumTime
        ]);

    end


    %% -----------------------------------------------------
    % 横轴 t
    % 数学符号使用 LaTeX
    % 不加粗
    % ------------------------------------------------------

    xlabel( ...
        ax, ...
        '$t$', ...
        'Interpreter', 'latex', ...
        'FontSize', 18, ...
        'FontWeight', 'normal');


    %% -----------------------------------------------------
    % 纵轴 rho_A、rho_B、rho_C、rho_D
    % 数学符号使用 LaTeX
    % 不加粗
    % ------------------------------------------------------

    ylabel( ...
        ax, ...
        strategyYLabels{strategyIdx}, ...
        'Interpreter', 'latex', ...
        'FontSize', 18, ...
        'FontWeight', 'normal');


    %% -----------------------------------------------------
    % 图例
    % 数学符号使用 LaTeX
    % 不加粗
    % ------------------------------------------------------

    legendHandles(strategyIdx) = legend( ...
        ax, ...
        lineHandles, ...
        legendLabels, ...
        'Interpreter', 'latex', ...
        'Location', 'best', ...
        'FontSize', 18, ...
        'FontWeight', 'normal', ...
        'Box', 'on');


    % 防止后续操作改变图例
    set( ...
        legendHandles(strategyIdx), ...
        'AutoUpdate', 'off', ...
        'Visible', 'on');


    %% -----------------------------------------------------
    % 坐标刻度字体
    % Times New Roman
    % 不加粗
    % ------------------------------------------------------

    set( ...
        ax, ...
        'FontName', 'Times New Roman', ...
        'FontSize', 18, ...
        'FontWeight', 'normal', ...
        'LineWidth', 1.4, ...
        'TickDir', 'in', ...
        'TickLength', [0.015, 0.015], ...
        'Layer', 'top');


    %% -----------------------------------------------------
    % 确保 LaTeX 和图例完成渲染
    % ------------------------------------------------------

    drawnow;


    tightInsetValue = get(ax, 'TightInset');


    looseInsetValue = max( ...
        tightInsetValue, ...
        [0.02 0.02 0.02 0.02]);


    set( ...
        ax, ...
        'LooseInset', ...
        looseInsetValue);


    drawnow;

end


%% =========================================================
% 18. 输出不同参数下最终策略比例
% ==========================================================

fprintf('\n不同参数下最终时刻的策略比例：\n');


finalResult = nan(numParams, 5);


for paramIdx = 1:numParams

    finalRho = ...
        dataAll{paramIdx}.rho(end, :);


    finalResult(paramIdx, :) = [
        paramValues(paramIdx), ...
        finalRho
    ];

end


if strcmp(paramSymbol, 'theta')

    firstVariableName = 'theta';


elseif strcmp(paramSymbol, 'p')

    firstVariableName = 'p';


elseif strcmp(paramSymbol, 's')

    firstVariableName = 's';


else

    firstVariableName = 'parameter';

end


resultTable = array2table( ...
    finalResult, ...
    'VariableNames', {
        firstVariableName, ...
        'rhoA', ...
        'rhoB', ...
        'rhoC', ...
        'rhoD'
    });


disp(resultTable);


%% =========================================================
% 19. 输出各参数组的数据长度
% ==========================================================

fprintf('\n各参数组的数据点数量：\n');


for paramIdx = 1:numParams

    fprintf( ...
        '%s = %.4g：%d 个数据点，时间范围为 %.4g 至 %.4g\n', ...
        paramSymbol, ...
        paramValues(paramIdx), ...
        size(dataAll{paramIdx}.rho, 1), ...
        dataAll{paramIdx}.t(1), ...
        dataAll{paramIdx}.t(end));

end


%% =========================================================
% 20. 自动导出 PDF
% ==========================================================

if savePDF

    % 确保所有 LaTeX 和图例完全渲染
    drawnow;


    for strategyIdx = 1:4

        outputFile = fullfile( ...
            dataFolder, ...
            [figureNames{strategyIdx}, '.pdf']);


        % 导出整个 Figure，
        % 避免图例在 PDF 中丢失
        exportgraphics( ...
            figureHandles(strategyIdx), ...
            outputFile, ...
            'ContentType', 'vector', ...
            'BackgroundColor', 'white');


        fprintf( ...
            'PDF 已保存：\n%s\n', ...
            outputFile);

    end

end


%% =============================================================
% 辅助函数 1：
% 安全地将单元格内容转换为字符串
% =============================================================

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


%% =============================================================
% 辅助函数 2：
% 将 cell 数据块转换为 double 矩阵
% =============================================================

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