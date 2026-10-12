%% plot_smooth_p_theta_heatmap.m
% 功能：
% 1. 自动扫描当前脚本所在文件夹中的所有 Excel 文件；
% 2. 自动扫描每个 Excel 文件中的所有工作表；
% 3. 自动识别 p-theta 平台收益矩阵；
% 4. 将横坐标统一设置为 p，纵坐标统一设置为 theta；
% 5. 通过二维插值绘制光滑热力图；
% 6. 不显示单元格数字，不显示网格或色块边界；
% 7. 自动保存 PNG 和 PDF 图片。
%
% 最终绘图格式：
% 1. 数学变量使用 LaTeX；
% 2. 普通英文和刻度使用 Times New Roman；
% 3. 坐标轴标签与 colorbar 标题：18 pt；
% 4. 坐标刻度与 colorbar 刻度：16 pt；
% 5. 所有文字均不加粗；
% 6. 坐标轴刻度朝内；
% 7. 主坐标轴线宽为 1.4；
% 8. colorbar 高度与主图基本一致；
% 9. 保留 parula 色带和原有插值设置。

clear;
clc;
close all;


%% =========================================================
% 1. 获取脚本所在文件夹
% ==========================================================

scriptFullPath = mfilename('fullpath');

if isempty(scriptFullPath)

    dataFolder = pwd;

else

    dataFolder = fileparts(scriptFullPath);

end

fprintf('当前数据文件夹：\n%s\n\n', dataFolder);


%% =========================================================
% 2. 文件读取设置
% ==========================================================

% 留空表示自动扫描当前文件夹中的所有 xlsx 文件
manualFileName = '';

% 示例：
% manualFileName = 'joint_p_theta_platform_revenue.xlsx';


% 留空表示扫描 Excel 中的所有工作表
manualSheetName = '';

% 示例：
% manualSheetName = 'SteadyRevenue';


%% =========================================================
% 3. 自动识别设置
% ==========================================================

% 最少需要多少个 p 和 theta 取值
minimumAxisLength = 4;


% 优先使用工作表名称中包含以下关键词的数据表
preferredSheetKeywords = [
    "steadyrevenue"
    "platformrevenue"
    "revenue"
    "平台收益"
    "稳态收益"
    "收益"
];


% 排除标准误、策略比例等工作表
excludedSheetKeywords = [
    "se_revenue"
    "stderr"
    "standarderror"
    "replicate"
    "steady_a"
    "steady_b"
    "steady_c"
    "steady_d"
    "strategy"
    "标准误"
];


%% =========================================================
% 4. 平滑插值设置
% ==========================================================

% p 方向插值点数
numberOfFinePPoints = 350;


% theta 方向插值点数
numberOfFineThetaPoints = 350;


% 插值方法
interpolationMethod = 'cubic';


% 是否限制插值结果不超过原始数据范围
limitInterpolatedValues = true;


%% =========================================================
% 5. 绘图设置
% ==========================================================

% 是否显示图标题
showTitle = false;


% 是否显示颜色条
showColorbar = true;


% 是否保存图片
saveFigure = true;


% 图片输出分辨率
exportResolution = 600;


% 输出文件名
outputPngName = ...
    'smooth_heatmap_p_theta.png';

outputPdfName = ...
    'smooth_heatmap_p_theta.pdf';


%% =========================================================
% 6. 扫描 Excel 文件并识别收益矩阵
% ==========================================================

fprintf('正在扫描Excel文件及工作表……\n\n');


[selectedFile, ...
 selectedSheet, ...
 headerRow, ...
 headerColumn, ...
 rowAxisName, ...
 columnAxisName, ...
 rowAxisValues, ...
 columnAxisValues, ...
 rawRevenueMatrix] = ...
    findRevenueMatrixInFolder( ...
        dataFolder, ...
        manualFileName, ...
        manualSheetName, ...
        minimumAxisLength, ...
        preferredSheetKeywords, ...
        excludedSheetKeywords);


fprintf('已识别平台收益数据：\n');

fprintf('Excel文件：%s\n', ...
    selectedFile);

fprintf('工作表：%s\n', ...
    selectedSheet);

fprintf('数据表左上角：第%d行，第%d列\n', ...
    headerRow, ...
    headerColumn);

fprintf('原始行参数：%s\n', ...
    rowAxisName);

fprintf('原始列参数：%s\n\n', ...
    columnAxisName);


%% =========================================================
% 7. 自动修复明显的坐标轴录入错误
% ==========================================================

rowAxisValues = ...
    repairAxisSequence( ...
        rowAxisValues, ...
        rowAxisName);


columnAxisValues = ...
    repairAxisSequence( ...
        columnAxisValues, ...
        columnAxisName);


%% =========================================================
% 8. 将数据统一转换为：
% 行 = theta
% 列 = p
% ==========================================================

rowAxisNameNormalized = ...
    normalizeAxisName(rowAxisName);


columnAxisNameNormalized = ...
    normalizeAxisName(columnAxisName);


if rowAxisNameNormalized == "p" && ...
        columnAxisNameNormalized == "theta"

    % 原表：行为 p，列为 theta
    % 转置后统一为：
    % 行 = theta
    % 列 = p

    pValues = ...
        rowAxisValues(:)';


    thetaValues = ...
        columnAxisValues(:);


    revenueMatrix = ...
        rawRevenueMatrix';


elseif rowAxisNameNormalized == "theta" && ...
        columnAxisNameNormalized == "p"

    thetaValues = ...
        rowAxisValues(:);


    pValues = ...
        columnAxisValues(:)';


    revenueMatrix = ...
        rawRevenueMatrix;


else

    error(['无法确定p和theta的排列方向。', ...
        '请检查左上角表头是否类似p\theta或theta\p。']);

end


%% =========================================================
% 9. 删除全为空的数据行和数据列
% ==========================================================

validThetaRows = ...
    any(isfinite(revenueMatrix), 2);


validPColumns = ...
    any(isfinite(revenueMatrix), 1);


thetaValues = ...
    thetaValues(validThetaRows);


pValues = ...
    pValues(validPColumns);


revenueMatrix = ...
    revenueMatrix( ...
        validThetaRows, ...
        validPColumns);


%% =========================================================
% 10. 按 p 和 theta 从小到大排序
% ==========================================================

[pValues, pSortOrder] = ...
    sort(pValues);


revenueMatrix = ...
    revenueMatrix(:, pSortOrder);


[thetaValues, thetaSortOrder] = ...
    sort(thetaValues);


revenueMatrix = ...
    revenueMatrix(thetaSortOrder, :);


%% =========================================================
% 11. 检查并处理重复坐标
% ==========================================================

[pValues, uniquePIndex] = ...
    unique(pValues, 'stable');


revenueMatrix = ...
    revenueMatrix(:, uniquePIndex);


[thetaValues, uniqueThetaIndex] = ...
    unique(thetaValues, 'stable');


revenueMatrix = ...
    revenueMatrix(uniqueThetaIndex, :);


if numel(pValues) < minimumAxisLength

    error( ...
        '有效p取值少于%d个，无法进行平滑插值。', ...
        minimumAxisLength);

end


if numel(thetaValues) < minimumAxisLength

    error( ...
        '有效theta取值少于%d个，无法进行平滑插值。', ...
        minimumAxisLength);

end


%% =========================================================
% 12. 填补收益矩阵中的少量缺失值
% ==========================================================

if any(~isfinite(revenueMatrix), 'all')

    warning( ...
        '收益矩阵中存在缺失值，程序将进行线性填补。');


    revenueMatrix = fillmissing( ...
        revenueMatrix, ...
        'linear', ...
        2, ...
        'EndValues', ...
        'nearest');


    revenueMatrix = fillmissing( ...
        revenueMatrix, ...
        'linear', ...
        1, ...
        'EndValues', ...
        'nearest');

end


if any(~isfinite(revenueMatrix), 'all')

    error('填补后收益矩阵中仍存在无效数据。');

end


%% =========================================================
% 13. 输出整理后的数据
% ==========================================================

fprintf('整理后的p取值：\n');

disp(pValues);


fprintf('整理后的theta取值：\n');

disp(thetaValues');


fprintf( ...
    '收益矩阵尺寸：%d × %d\n\n', ...
    size(revenueMatrix, 1), ...
    size(revenueMatrix, 2));


%% =========================================================
% 14. 构造原始参数网格
% ==========================================================

[PGrid, ThetaGrid] = meshgrid( ...
    pValues, ...
    thetaValues);


%% =========================================================
% 15. 构造高分辨率平滑网格
% ==========================================================

finePValues = linspace( ...
    min(pValues), ...
    max(pValues), ...
    numberOfFinePPoints);


fineThetaValues = linspace( ...
    min(thetaValues), ...
    max(thetaValues), ...
    numberOfFineThetaPoints);


[PFineGrid, ThetaFineGrid] = meshgrid( ...
    finePValues, ...
    fineThetaValues);


%% =========================================================
% 16. 二维插值得到光滑收益平面
% ==========================================================

smoothRevenueMatrix = interp2( ...
    PGrid, ...
    ThetaGrid, ...
    revenueMatrix, ...
    PFineGrid, ...
    ThetaFineGrid, ...
    interpolationMethod);


%% =========================================================
% 17. 限制插值结果范围，防止过冲
% ==========================================================

if limitInterpolatedValues

    minimumOriginalRevenue = ...
        min(revenueMatrix, [], 'all');


    maximumOriginalRevenue = ...
        max(revenueMatrix, [], 'all');


    smoothRevenueMatrix = max( ...
        smoothRevenueMatrix, ...
        minimumOriginalRevenue);


    smoothRevenueMatrix = min( ...
        smoothRevenueMatrix, ...
        maximumOriginalRevenue);

end


%% =========================================================
% 18. 创建图窗
% ==========================================================

fig = figure( ...
    'Color', 'w', ...
    'Units', 'centimeters', ...
    'Position', [4, 3, 16.5, 12.5], ...
    'Name', 'Smooth p-theta heatmap', ...
    'NumberTitle', 'off', ...
    'Renderer', 'opengl');


% 主图稍微向左放，
% 给右侧 colorbar 和文字留出空间

ax = axes( ...
    'Parent', fig, ...
    'Units', 'normalized', ...
    'Position', [0.13, 0.14, 0.67, 0.76]);


hold(ax, 'on');


%% =========================================================
% 19. 绘制光滑热力图
% ==========================================================

surfaceHandle = surf( ...
    ax, ...
    PFineGrid, ...
    ThetaFineGrid, ...
    smoothRevenueMatrix, ...
    'EdgeColor', 'none', ...
    'FaceColor', 'interp');


% 从正上方观察，形成二维热力图
view(ax, 2);


% 消除网格线并平滑着色
shading(ax, 'interp');


hold(ax, 'off');


%% =========================================================
% 20. 设置颜色方案
% ==========================================================

% 保持 parula 色带
colormap(ax, parula(256));


% 颜色范围采用原始数据最小值和最大值
colorLimits = [ ...
    min(revenueMatrix, [], 'all'), ...
    max(revenueMatrix, [], 'all') ...
];


if colorLimits(1) == colorLimits(2)

    colorLimits = [ ...
        colorLimits(1) - 1, ...
        colorLimits(2) + 1 ...
    ];

end


clim(ax, colorLimits);


%% =========================================================
% 21. 设置坐标轴范围
% ==========================================================

xlim(ax, [ ...
    min(pValues), ...
    max(pValues) ...
]);


ylim(ax, [ ...
    min(thetaValues), ...
    max(thetaValues) ...
]);


%% =========================================================
% 22. 设置坐标轴刻度
% ==========================================================

% 最多显示6个 p 刻度
numberOfPTicks = min( ...
    6, ...
    numel(pValues));


pTickIndex = unique( ...
    round( ...
        linspace( ...
            1, ...
            numel(pValues), ...
            numberOfPTicks)));


xticks( ...
    ax, ...
    pValues(pTickIndex));


% 最多显示6个 theta 刻度
numberOfThetaTicks = min( ...
    6, ...
    numel(thetaValues));


thetaTickIndex = unique( ...
    round( ...
        linspace( ...
            1, ...
            numel(thetaValues), ...
            numberOfThetaTicks)));


yticks( ...
    ax, ...
    thetaValues(thetaTickIndex));


%% =========================================================
% 23. 设置坐标轴标签
% ==========================================================

% 数学变量 p：
% LaTeX
% 18 pt
% 不加粗

xlabel( ...
    ax, ...
    '$p$', ...
    'Interpreter', 'latex', ...
    'FontSize', 18, ...
    'FontWeight', 'normal');


% 数学变量 theta：
% LaTeX
% 18 pt
% 不加粗

ylabel( ...
    ax, ...
    '$\theta$', ...
    'Interpreter', 'latex', ...
    'FontSize', 18, ...
    'FontWeight', 'normal');


%% =========================================================
% 24. 可选标题
% ==========================================================

if showTitle

    title( ...
        ax, ...
        ['Joint effects of knowledge price and ', ...
         'revenue-sharing ratio'], ...
        'Interpreter', 'tex', ...
        'FontName', 'Times New Roman', ...
        'FontSize', 18, ...
        'FontWeight', 'normal');

end


%% =========================================================
% 25. 设置主坐标轴外观
% ==========================================================

grid(ax, 'off');


box(ax, 'on');


% 坐标刻度：
% Times New Roman
% 16 pt
% 不加粗

set( ...
    ax, ...
    'FontName', 'Times New Roman', ...
    'FontSize', 16, ...
    'FontWeight', 'normal', ...
    'LineWidth', 1.4, ...
    'TickDir', 'in', ...
    'TickLength', [0.015, 0.015], ...
    'Layer', 'top');


% 图形比例稍微接近方形
pbaspect(ax, [1.15, 1, 1]);


%% =========================================================
% 26. 添加颜色条
% ==========================================================

if showColorbar

    colorBarHandle = colorbar( ...
        ax, ...
        'eastoutside');


    colorBarHandle.Units = ...
        'normalized';


    % -----------------------------------------------------
    % 调整 colorbar 大小
    %
    % [left, bottom, width, height]
    %
    % 与主图高度基本保持一致，
    % 避免原来 colorbar 明显偏短
    % -----------------------------------------------------

    colorBarHandle.Position = [ ...
        0.835, ...   % 左右位置
        0.140, ...   % 与主图底部对齐
        0.027, ...   % 颜色条宽度
        0.760  ...   % 与主图高度一致
    ];


    % colorbar 标题
    colorBarHandle.Label.String = ...
        'Steady-state platform revenue';


    colorBarHandle.Label.Interpreter = ...
        'tex';


    colorBarHandle.Label.FontName = ...
        'Times New Roman';


    colorBarHandle.Label.FontSize = ...
        18;


    colorBarHandle.Label.FontWeight = ...
        'normal';


    % colorbar 刻度
    colorBarHandle.FontName = ...
        'Times New Roman';


    colorBarHandle.FontSize = ...
        16;


    colorBarHandle.FontWeight = ...
        'normal';


    colorBarHandle.LineWidth = ...
        1.0;


    colorBarHandle.TickDirection = ...
        'in';

end


%% =========================================================
% 27. 输出最大收益对应的参数组合
% ==========================================================

[maximumRevenue, maximumLinearIndex] = ...
    max( ...
        revenueMatrix, ...
        [], ...
        'all', ...
        'linear');


[maximumThetaIndex, maximumPIndex] = ...
    ind2sub( ...
        size(revenueMatrix), ...
        maximumLinearIndex);


fprintf( ...
    '最大平台稳态收益：%.6f\n', ...
    maximumRevenue);


fprintf( ...
    '对应知识价格p：%.4f\n', ...
    pValues(maximumPIndex));


fprintf( ...
    '对应分成比例theta：%.4f\n\n', ...
    thetaValues(maximumThetaIndex));


%% =========================================================
% 28. 保存图片
% ==========================================================

if saveFigure

    outputPngFile = fullfile( ...
        dataFolder, ...
        outputPngName);


    outputPdfFile = fullfile( ...
        dataFolder, ...
        outputPdfName);


    exportgraphics( ...
        fig, ...
        outputPngFile, ...
        'Resolution', ...
        exportResolution);


    exportgraphics( ...
        fig, ...
        outputPdfFile, ...
        'ContentType', ...
        'vector');


    fprintf( ...
        'PNG图片已保存至：\n%s\n\n', ...
        outputPngFile);


    fprintf( ...
        'PDF图片已保存至：\n%s\n', ...
        outputPdfFile);

end


%% ========================================================================
% 局部函数1：
% 扫描文件夹中的所有 Excel 文件和工作表
% ========================================================================

function [selectedFile, ...
          selectedSheet, ...
          selectedHeaderRow, ...
          selectedHeaderColumn, ...
          selectedRowAxisName, ...
          selectedColumnAxisName, ...
          selectedRowAxisValues, ...
          selectedColumnAxisValues, ...
          selectedRevenueMatrix] = ...
    findRevenueMatrixInFolder( ...
        dataFolder, ...
        manualFileName, ...
        manualSheetName, ...
        minimumAxisLength, ...
        preferredSheetKeywords, ...
        excludedSheetKeywords)


    if isempty(manualFileName)

        excelFiles = dir( ...
            fullfile(dataFolder, '*.xlsx'));

    else

        excelFiles = dir( ...
            fullfile(dataFolder, manualFileName));

    end


    if isempty(excelFiles)

        error('当前文件夹中没有找到xlsx文件。');

    end


    temporaryFileFlag = startsWith( ...
        {excelFiles.name}, ...
        '~$');


    excelFiles = ...
        excelFiles(~temporaryFileFlag);


    if isempty(excelFiles)

        error('当前文件夹中没有有效的xlsx文件。');

    end


    candidates = struct( ...
        'file', {}, ...
        'sheet', {}, ...
        'headerRow', {}, ...
        'headerColumn', {}, ...
        'rowAxisName', {}, ...
        'columnAxisName', {}, ...
        'rowAxisValues', {}, ...
        'columnAxisValues', {}, ...
        'revenueMatrix', {}, ...
        'score', {}, ...
        'modifiedTime', {});


    candidateCount = 0;


    for fileIndex = 1:numel(excelFiles)

        currentFile = fullfile( ...
            dataFolder, ...
            excelFiles(fileIndex).name);


        try

            currentSheetNames = ...
                getExcelSheetNames(currentFile);

        catch

            warning( ...
                '无法读取Excel文件：%s', ...
                currentFile);

            continue;

        end


        if ~isempty(manualSheetName)

            sheetMatch = strcmpi( ...
                string(currentSheetNames), ...
                string(manualSheetName));


            currentSheetNames = ...
                currentSheetNames(sheetMatch);

        end


        for sheetIndex = 1:numel(currentSheetNames)

            currentSheet = ...
                currentSheetNames{sheetIndex};


            normalizedSheetName = lower( ...
                erase( ...
                    string(currentSheet), ...
                    " "));


            isExcludedSheet = false;


            for keywordIndex = ...
                    1:numel(excludedSheetKeywords)

                if contains( ...
                        normalizedSheetName, ...
                        lower( ...
                            excludedSheetKeywords( ...
                                keywordIndex)))

                    isExcludedSheet = true;

                    break;

                end

            end


            if isExcludedSheet

                continue;

            end


            try

                rawData = readcell( ...
                    currentFile, ...
                    'Sheet', ...
                    currentSheet);

            catch

                continue;

            end


            if isempty(rawData)

                continue;

            end


            sheetCandidates = ...
                locateMatricesInSheet( ...
                    rawData, ...
                    minimumAxisLength);


            if isempty(sheetCandidates)

                continue;

            end


            for localCandidateIndex = ...
                    1:numel(sheetCandidates)

                currentCandidate = ...
                    sheetCandidates(localCandidateIndex);


                candidateScore = ...
                    currentCandidate.dataCount;


                for keywordIndex = ...
                        1:numel(preferredSheetKeywords)

                    if contains( ...
                            normalizedSheetName, ...
                            lower( ...
                                preferredSheetKeywords( ...
                                    keywordIndex)))

                        candidateScore = ...
                            candidateScore + 10000;

                        break;

                    end

                end


                validRevenue = ...
                    currentCandidate.revenueMatrix( ...
                        isfinite( ...
                            currentCandidate.revenueMatrix));


                if ~isempty(validRevenue) && ...
                        median(abs(validRevenue)) > 1

                    candidateScore = ...
                        candidateScore + 1000;

                end


                candidateCount = ...
                    candidateCount + 1;


                candidates(candidateCount).file = ...
                    currentFile;


                candidates(candidateCount).sheet = ...
                    currentSheet;


                candidates(candidateCount).headerRow = ...
                    currentCandidate.headerRow;


                candidates(candidateCount).headerColumn = ...
                    currentCandidate.headerColumn;


                candidates(candidateCount).rowAxisName = ...
                    currentCandidate.rowAxisName;


                candidates(candidateCount).columnAxisName = ...
                    currentCandidate.columnAxisName;


                candidates(candidateCount).rowAxisValues = ...
                    currentCandidate.rowAxisValues;


                candidates(candidateCount).columnAxisValues = ...
                    currentCandidate.columnAxisValues;


                candidates(candidateCount).revenueMatrix = ...
                    currentCandidate.revenueMatrix;


                candidates(candidateCount).score = ...
                    candidateScore;


                candidates(candidateCount).modifiedTime = ...
                    excelFiles(fileIndex).datenum;

            end

        end

    end


    if isempty(candidates)

        error([ ...
            '没有在当前文件夹中识别到p-theta收益矩阵。', ...
            newline, ...
            '请检查Excel表左上角是否包含p和theta，', ...
            '且右侧和下方为连续数值。']);

    end


    candidateScores = [ ...
        candidates.score ...
    ];


    maximumScore = ...
        max(candidateScores);


    bestCandidateIndices = find( ...
        candidateScores == maximumScore);


    if numel(bestCandidateIndices) > 1

        modifiedTimes = [ ...
            candidates( ...
                bestCandidateIndices).modifiedTime ...
        ];


        [~, newestIndex] = ...
            max(modifiedTimes);


        selectedIndex = ...
            bestCandidateIndices(newestIndex);

    else

        selectedIndex = ...
            bestCandidateIndices(1);

    end


    selectedCandidate = ...
        candidates(selectedIndex);


    if numel(candidates) > 1

        fprintf( ...
            '共识别到%d个候选数据表。\n', ...
            numel(candidates));


        fprintf( ...
            '程序自动选择得分最高的数据表。\n\n');

    end


    selectedFile = ...
        selectedCandidate.file;


    selectedSheet = ...
        selectedCandidate.sheet;


    selectedHeaderRow = ...
        selectedCandidate.headerRow;


    selectedHeaderColumn = ...
        selectedCandidate.headerColumn;


    selectedRowAxisName = ...
        selectedCandidate.rowAxisName;


    selectedColumnAxisName = ...
        selectedCandidate.columnAxisName;


    selectedRowAxisValues = ...
        selectedCandidate.rowAxisValues;


    selectedColumnAxisValues = ...
        selectedCandidate.columnAxisValues;


    selectedRevenueMatrix = ...
        selectedCandidate.revenueMatrix;

end


%% ========================================================================
% 局部函数2：
% 在一个工作表中寻找 p-theta 矩阵
% ========================================================================

function candidates = ...
    locateMatricesInSheet( ...
        rawData, ...
        minimumAxisLength)


    candidates = struct( ...
        'headerRow', {}, ...
        'headerColumn', {}, ...
        'rowAxisName', {}, ...
        'columnAxisName', {}, ...
        'rowAxisValues', {}, ...
        'columnAxisValues', {}, ...
        'revenueMatrix', {}, ...
        'dataCount', {});


    candidateCount = 0;


    [numberOfRows, numberOfColumns] = ...
        size(rawData);


    maximumSearchRow = ...
        min(numberOfRows, 60);


    maximumSearchColumn = ...
        min(numberOfColumns, 40);


    for rowIndex = 1:maximumSearchRow

        for columnIndex = 1:maximumSearchColumn

            headerText = ...
                safeCellToString( ...
                    rawData{ ...
                        rowIndex, ...
                        columnIndex});


            if strlength(headerText) == 0

                continue;

            end


            [hasP, ...
             hasTheta, ...
             rowAxisName, ...
             columnAxisName] = ...
                parseAxisHeader(headerText);


            if ~(hasP && hasTheta)

                continue;

            end


            columnAxisValues = [];


            for currentColumn = ...
                    columnIndex + 1:numberOfColumns

                currentValue = ...
                    cellToNumericScalar( ...
                        rawData{ ...
                            rowIndex, ...
                            currentColumn});


                if ~isfinite(currentValue)

                    break;

                end


                columnAxisValues(end + 1) = ...
                    currentValue; %#ok<AGROW>

            end


            rowAxisValues = [];


            for currentRow = ...
                    rowIndex + 1:numberOfRows

                currentValue = ...
                    cellToNumericScalar( ...
                        rawData{ ...
                            currentRow, ...
                            columnIndex});


                if ~isfinite(currentValue)

                    break;

                end


                rowAxisValues(end + 1, 1) = ...
                    currentValue; %#ok<AGROW>

            end


            if numel(columnAxisValues) < minimumAxisLength || ...
                    numel(rowAxisValues) < minimumAxisLength

                continue;

            end


            revenueMatrix = nan( ...
                numel(rowAxisValues), ...
                numel(columnAxisValues));


            for matrixRow = 1:numel(rowAxisValues)

                for matrixColumn = ...
                        1:numel(columnAxisValues)

                    revenueMatrix( ...
                        matrixRow, ...
                        matrixColumn) = ...
                            cellToNumericScalar( ...
                                rawData{ ...
                                    rowIndex + matrixRow, ...
                                    columnIndex + matrixColumn});

                end

            end


            validDataCount = ...
                nnz(isfinite(revenueMatrix));


            validDataRatio = ...
                validDataCount / numel(revenueMatrix);


            if validDataRatio < 0.80

                continue;

            end


            candidateCount = ...
                candidateCount + 1;


            candidates(candidateCount).headerRow = ...
                rowIndex;


            candidates(candidateCount).headerColumn = ...
                columnIndex;


            candidates(candidateCount).rowAxisName = ...
                rowAxisName;


            candidates(candidateCount).columnAxisName = ...
                columnAxisName;


            candidates(candidateCount).rowAxisValues = ...
                rowAxisValues;


            candidates(candidateCount).columnAxisValues = ...
                columnAxisValues;


            candidates(candidateCount).revenueMatrix = ...
                revenueMatrix;


            candidates(candidateCount).dataCount = ...
                validDataCount;

        end

    end

end


%% ========================================================================
% 局部函数3：
% 解析左上角表头中的行参数和列参数
% ========================================================================

function [hasP, ...
          hasTheta, ...
          rowAxisName, ...
          columnAxisName] = ...
    parseAxisHeader(headerText)


    normalizedHeader = lower( ...
        string(headerText));


    normalizedHeader = replace( ...
        normalizedHeader, ...
        "θ", ...
        "theta");


    normalizedHeader = replace( ...
        normalizedHeader, ...
        "ϑ", ...
        "theta");


    normalizedHeader = erase( ...
        normalizedHeader, ...
        " ");


    hasP = contains( ...
        normalizedHeader, ...
        "p");


    hasTheta = contains( ...
        normalizedHeader, ...
        "theta");


    rowAxisName = "";

    columnAxisName = "";


    if ~(hasP && hasTheta)

        return;

    end


    normalizedHeader = replace( ...
        normalizedHeader, ...
        "/", ...
        "\");


    normalizedHeader = replace( ...
        normalizedHeader, ...
        "-", ...
        "\");


    normalizedHeader = replace( ...
        normalizedHeader, ...
        "_", ...
        "\");


    pPosition = strfind( ...
        normalizedHeader, ...
        "p");


    thetaPosition = strfind( ...
        normalizedHeader, ...
        "theta");


    pPosition = ...
        pPosition(1);


    thetaPosition = ...
        thetaPosition(1);


    if pPosition < thetaPosition

        rowAxisName = "p";

        columnAxisName = "theta";

    else

        rowAxisName = "theta";

        columnAxisName = "p";

    end

end


%% ========================================================================
% 局部函数4：
% 修复明显不连续的参数坐标
% ========================================================================

function repairedAxis = ...
    repairAxisSequence( ...
        inputAxis, ...
        axisName)


    repairedAxis = ...
        inputAxis(:);


    if numel(repairedAxis) < 3

        return;

    end


    positiveDifferences = ...
        diff(repairedAxis);


    positiveDifferences = ...
        positiveDifferences( ...
            positiveDifferences > 0);


    if isempty(positiveDifferences)

        return;

    end


    typicalStep = ...
        median(positiveDifferences);


    tolerance = max( ...
        1e-10, ...
        abs(typicalStep) * 0.15);


    for index = 2:numel(repairedAxis)-1

        previousValue = ...
            repairedAxis(index - 1);


        currentValue = ...
            repairedAxis(index);


        nextValue = ...
            repairedAxis(index + 1);


        expectedValue = ...
            previousValue + typicalStep;


        if currentValue <= previousValue && ...
                nextValue > previousValue


            midpointValue = ...
                (previousValue + nextValue) / 2;


            if abs(midpointValue - expectedValue) <= ...
                    max( ...
                        tolerance, ...
                        abs(typicalStep) * 0.25)


                warning([ ...
                    '%s坐标中的第%d个值%.6g不连续，', ...
                    '程序根据前后坐标将其修复为%.6g。'], ...
                    axisName, ...
                    index, ...
                    currentValue, ...
                    midpointValue);


                repairedAxis(index) = ...
                    midpointValue;

            end

        end

    end

end


%% ========================================================================
% 局部函数5：
% 统一参数名称
% ========================================================================

function normalizedName = ...
    normalizeAxisName(inputName)


    normalizedName = lower( ...
        string(inputName));


    normalizedName = replace( ...
        normalizedName, ...
        "θ", ...
        "theta");


    normalizedName = replace( ...
        normalizedName, ...
        "ϑ", ...
        "theta");


    normalizedName = erase( ...
        normalizedName, ...
        " ");

end


%% ========================================================================
% 局部函数6：
% 获取 Excel 工作表名称
% ========================================================================

function sheetNameList = ...
    getExcelSheetNames(excelFile)


    try

        sheetNameList = ...
            sheetnames(excelFile);


        sheetNameList = ...
            cellstr(sheetNameList);


    catch

        [~, sheetNameList] = ...
            xlsfinfo(excelFile);

    end


    if isempty(sheetNameList)

        error('Excel文件中没有可读取的工作表。');

    end

end


%% ========================================================================
% 局部函数7：
% 将 Excel 单元格安全转换为数值
% ========================================================================

function numericValue = ...
    cellToNumericScalar(cellValue)


    numericValue = NaN;


    if isempty(cellValue)

        return;

    end


    if isnumeric(cellValue)

        if isscalar(cellValue) && ...
                isfinite(cellValue)

            numericValue = ...
                double(cellValue);

        end

        return;

    end


    if islogical(cellValue)

        if isscalar(cellValue)

            numericValue = ...
                double(cellValue);

        end

        return;

    end


    if ischar(cellValue)

        convertedValue = ...
            str2double(strtrim(cellValue));


        if isfinite(convertedValue)

            numericValue = ...
                convertedValue;

        end

        return;

    end


    if isstring(cellValue)

        if isscalar(cellValue) && ...
                ~ismissing(cellValue)

            convertedValue = ...
                str2double(strtrim(cellValue));


            if isfinite(convertedValue)

                numericValue = ...
                    convertedValue;

            end

        end

        return;

    end


    try

        convertedValue = ...
            str2double(string(cellValue));


        if isscalar(convertedValue) && ...
                isfinite(convertedValue)

            numericValue = ...
                convertedValue;

        end


    catch

        numericValue = NaN;

    end

end


%% ========================================================================
% 局部函数8：
% 将 Excel 单元格安全转换为字符串
% ========================================================================

function outputText = ...
    safeCellToString(cellValue)


    if isempty(cellValue)

        outputText = "";

        return;

    end


    if ischar(cellValue)

        outputText = ...
            string(strtrim(cellValue));

        return;

    end


    if isstring(cellValue)

        if isscalar(cellValue) && ...
                ~ismissing(cellValue)

            outputText = ...
                strtrim(cellValue);

        else

            outputText = "";

        end

        return;

    end


    try

        outputText = ...
            strtrim( ...
                string(cellValue));


    catch

        outputText = "";

    end

end