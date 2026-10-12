%% plot_platform_revenue_with_inset.m
% 功能：
% 比较免费制、分成制和会员制的平台收益。
%
% 最终只生成一个图窗：
% 1. 主图：三种治理制度的平台收益完整演化过程；
% 2. 嵌入窗口：放大比较免费制与会员制的收益差异。
%
% Excel数据结构：
% 第1行：平台收益等说明文字
% 第2行：免费、分成、会员
% 第3行及以后：平台收益时间序列
%
% 程序根据第2行中的"免费""分成""会员"自动识别数据列。
%
% 统一绘图标准：
% 1. 数学变量使用 LaTeX；
% 2. 普通英文使用 Times New Roman；
% 3. 坐标刻度使用 Times New Roman；
% 4. 所有文字均不加粗；
% 5. 保持原有字体大小不变；
% 6. governance terminology 统一使用 regime。

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
% 2. 文件读取设置
% ==========================================================

% 留空时，程序自动查找包含"免费、分成、会员"表头的 Excel 文件
manualFileName = '';


% 也可以手动指定：
% manualFileName = '你的数据文件.xlsx';


sheetName = 'Sheet1';


% 治理制度名称所在行
headerRow = 2;


% 数值数据起始行
dataStartRow = 3;


%% =========================================================
% 3. 稳态与绘图参数设置
% ==========================================================

% 采用最后10%的数据计算稳态平台收益
steadyFraction = 0.10;


% 小窗口从整个仿真过程的50%位置开始显示
zoomStartFraction = 0.50;


% 绘图抽样间隔
% 数据量较大时，适当抽样可以提高绘图速度
plotEvery = 20;


% 是否显示主图网格
showMainGrid = false;


% 是否显示小窗口网格
showInsetGrid = false;


% 是否显示主图标题
showMainTitle = false;


% 是否显示小窗口标题
showInsetTitle = true;


% 是否显示主图中的稳态区间
showSteadyRegion = false;


% 是否自动保存图片
saveFigure = false;


% 图片输出分辨率
exportResolution = 600;


%% =========================================================
% 4. 主图和小窗口位置
% ==========================================================

% 主坐标轴位置：[左 下 宽 高]
mainAxesPosition = [ ...
    0.12, ...
    0.14, ...
    0.83, ...
    0.80];


% 嵌入式小窗口位置：[左 下 宽 高]
insetAxesPosition = [ ...
    0.565, ...
    0.225, ...
    0.325, ...
    0.295];


%% =========================================================
% 5. 查找 Excel 文件
% ==========================================================

if ~isempty(manualFileName)

    xlsxFile = fullfile( ...
        dataFolder, ...
        manualFileName);


    if ~isfile(xlsxFile)

        error( ...
            '没有找到指定的Excel文件：\n%s', ...
            xlsxFile);

    end

else

    xlsxFile = findRevenueWorkbook( ...
        dataFolder, ...
        sheetName, ...
        headerRow);

end


fprintf( ...
    '正在读取数据文件：\n%s\n\n', ...
    xlsxFile);


%% =========================================================
% 6. 读取 Excel 数据
% ==========================================================

raw = readcell( ...
    xlsxFile, ...
    'Sheet', sheetName);


[nRows, nCols] = size(raw);


if nRows < dataStartRow

    error('Excel文件中没有足够的数据行。');

end


%% =========================================================
% 7. 识别免费、分成和会员所在列
% ==========================================================

headerText = strings(1, nCols);


for colIdx = 1:nCols

    headerText(colIdx) = ...
        safeCellToString( ...
            raw{headerRow, colIdx});

end


headerText = strtrim(headerText);


freeCol = find( ...
    contains(headerText, "免费"), ...
    1, ...
    'first');


sharingCol = find( ...
    contains(headerText, "分成"), ...
    1, ...
    'first');


membershipCol = find( ...
    contains(headerText, "会员"), ...
    1, ...
    'first');


if isempty(freeCol)

    error( ...
        '第%d行中没有识别到"免费"列。', ...
        headerRow);

end


if isempty(sharingCol)

    error( ...
        '第%d行中没有识别到"分成"列。', ...
        headerRow);

end


if isempty(membershipCol)

    error( ...
        '第%d行中没有识别到"会员"列。', ...
        headerRow);

end


fprintf( ...
    '免费模式数据列：第%d列\n', ...
    freeCol);


fprintf( ...
    '分成模式数据列：第%d列\n', ...
    sharingCol);


fprintf( ...
    '会员模式数据列：第%d列\n\n', ...
    membershipCol);


%% =========================================================
% 8. 读取三种治理制度的平台收益
% ==========================================================

freeRevenue = cellColumnToDouble( ...
    raw(dataStartRow:end, freeCol));


sharingRevenue = cellColumnToDouble( ...
    raw(dataStartRow:end, sharingCol));


membershipRevenue = cellColumnToDouble( ...
    raw(dataStartRow:end, membershipCol));


%% =========================================================
% 9. 删除每列末尾的空白行
% ==========================================================

freeRevenue = ...
    trimTrailingNaN(freeRevenue);


sharingRevenue = ...
    trimTrailingNaN(sharingRevenue);


membershipRevenue = ...
    trimTrailingNaN(membershipRevenue);


if isempty(freeRevenue) || ...
        isempty(sharingRevenue) || ...
        isempty(membershipRevenue)

    error('至少有一种治理制度没有读取到有效的平台收益数据。');

end


%% =========================================================
% 10. 对齐三种治理制度的数据长度
% ==========================================================

numPoints = min([ ...
    numel(freeRevenue), ...
    numel(sharingRevenue), ...
    numel(membershipRevenue)]);


freeRevenue = ...
    freeRevenue(1:numPoints);


sharingRevenue = ...
    sharingRevenue(1:numPoints);


membershipRevenue = ...
    membershipRevenue(1:numPoints);


%% =========================================================
% 11. 删除内部缺失值
% ==========================================================

validRows = ...
    ~isnan(freeRevenue) & ...
    ~isnan(sharingRevenue) & ...
    ~isnan(membershipRevenue);


if ~all(validRows)

    warning(['数据中存在内部缺失值，', ...
        '程序将删除三种治理制度未同时有效的时间步。']);


    freeRevenue = ...
        freeRevenue(validRows);


    sharingRevenue = ...
        sharingRevenue(validRows);


    membershipRevenue = ...
        membershipRevenue(validRows);

end


numPoints = numel(freeRevenue);


if numPoints < 2

    error('有效数据点数量不足，无法绘图。');

end


% 时间步从0开始
timeSteps = (0:numPoints-1)';


fprintf( ...
    '有效时间步数量：%d\n\n', ...
    numPoints);


%% =========================================================
% 12. 计算三种治理制度的稳态平台收益
% ==========================================================

steadyWindowLength = ceil( ...
    steadyFraction * numPoints);


steadyWindowLength = max( ...
    steadyWindowLength, ...
    1);


steadyStartIndex = ...
    numPoints - steadyWindowLength + 1;


steadyFree = mean( ...
    freeRevenue(steadyStartIndex:end));


steadySharing = mean( ...
    sharingRevenue(steadyStartIndex:end));


steadyMembership = mean( ...
    membershipRevenue(steadyStartIndex:end));


% 计算会员制与免费制的差异
% 仅在命令窗口输出，不在图片中标注
membershipPremium = ...
    steadyMembership - steadyFree;


if steadyFree ~= 0

    membershipPremiumPercent = ...
        100 * membershipPremium / steadyFree;

else

    membershipPremiumPercent = NaN;

end


%% =========================================================
% 13. 输出稳态结果
% ==========================================================

regimeNames = [
    "Free regime"
    "Revenue-sharing regime"
    "Membership regime"
];


steadyRevenue = [
    steadyFree
    steadySharing
    steadyMembership
];


resultTable = table( ...
    regimeNames, ...
    steadyRevenue, ...
    'VariableNames', { ...
        'GovernanceRegime', ...
        'SteadyStateRevenue'});


fprintf( ...
    '稳态平台收益采用最后%.1f%%数据的平均值。\n\n', ...
    steadyFraction * 100);


disp(resultTable);


fprintf( ...
    '会员制与免费制的稳态收益差：%.6f\n', ...
    membershipPremium);


fprintf( ...
    '会员制相对免费制的收益增幅：%.6f%%\n\n', ...
    membershipPremiumPercent);


%% =========================================================
% 14. 设置高区分度配色
% ==========================================================

% 免费制：深蓝色
freeColor = [
    0.0000, ...
    0.2600, ...
    0.7200
];


% 分成制：橙黄色
sharingColor = [
    0.9500, ...
    0.5200, ...
    0.0800
];


% 会员制：深红色
membershipColor = [
    0.7800, ...
    0.0500, ...
    0.1500
];


% 免费制和会员制之间的差异阴影
differenceColor = [
    0.6500, ...
    0.4000, ...
    0.7000
];


% 稳态区域颜色
steadyRegionColor = [
    0.8500, ...
    0.8500, ...
    0.8500
];


%% =========================================================
% 15. 构造主图绘图抽样点
% ==========================================================

plotIndex = ...
    1:plotEvery:numPoints;


% 确保最后一个时间点被绘制
if plotIndex(end) ~= numPoints

    plotIndex = [ ...
        plotIndex, ...
        numPoints];

end


%% =========================================================
% 16. 创建图窗
% ==========================================================

fig = figure( ...
    'Color', 'w', ...
    'Units', 'centimeters', ...
    'Position', [4, 3, 18, 11.5], ...
    'Name', 'Platform revenue comparison with inset', ...
    'NumberTitle', 'off');


%% ========================================================================
% 主图：三种治理制度的平台收益
% ========================================================================

axMain = axes( ...
    'Parent', fig, ...
    'Position', mainAxesPosition);


hold(axMain, 'on');


%% =========================================================
% 17. 可选：标出稳态统计区间
% ==========================================================

if showSteadyRegion

    allRevenue = [ ...
        freeRevenue; ...
        sharingRevenue; ...
        membershipRevenue];


    mainMinimum = min(allRevenue);

    mainMaximum = max(allRevenue);


    steadyPatchX = [ ...
        timeSteps(steadyStartIndex); ...
        timeSteps(end); ...
        timeSteps(end); ...
        timeSteps(steadyStartIndex)];


    steadyPatchY = [ ...
        mainMinimum; ...
        mainMinimum; ...
        mainMaximum; ...
        mainMaximum];


    fill( ...
        axMain, ...
        steadyPatchX, ...
        steadyPatchY, ...
        steadyRegionColor, ...
        'FaceAlpha', 0.18, ...
        'EdgeColor', 'none', ...
        'HandleVisibility', 'off');

end


%% =========================================================
% 18. 绘制三种治理制度
% ==========================================================

lineFree = plot( ...
    axMain, ...
    timeSteps(plotIndex), ...
    freeRevenue(plotIndex), ...
    '-', ...
    'LineWidth', 1.9, ...
    'Color', freeColor);


lineSharing = plot( ...
    axMain, ...
    timeSteps(plotIndex), ...
    sharingRevenue(plotIndex), ...
    '-', ...
    'LineWidth', 1.9, ...
    'Color', sharingColor);


lineMembership = plot( ...
    axMain, ...
    timeSteps(plotIndex), ...
    membershipRevenue(plotIndex), ...
    '-', ...
    'LineWidth', 1.9, ...
    'Color', membershipColor);


hold(axMain, 'off');


%% =========================================================
% 19. 设置主图横坐标范围
% ==========================================================

xlim(axMain, [ ...
    timeSteps(1), ...
    timeSteps(end)]);


%% =========================================================
% 20. 设置主图纵坐标范围
% ==========================================================

minimumRevenue = min([ ...
    freeRevenue; ...
    sharingRevenue; ...
    membershipRevenue]);


maximumRevenue = max([ ...
    freeRevenue; ...
    sharingRevenue; ...
    membershipRevenue]);


revenueRange = ...
    maximumRevenue - minimumRevenue;


if revenueRange <= 0

    mainPadding = 1;

else

    mainPadding = ...
        0.05 * revenueRange;

end


if minimumRevenue >= 0

    ylim(axMain, [ ...
        0, ...
        maximumRevenue + mainPadding]);

else

    ylim(axMain, [ ...
        minimumRevenue - mainPadding, ...
        maximumRevenue + mainPadding]);

end


%% =========================================================
% 21. 设置主图坐标轴名称
% ==========================================================

% 数学变量 t 使用 LaTeX
xlabel( ...
    axMain, ...
    '$t$', ...
    'Interpreter', 'latex', ...
    'FontSize', 16, ...
    'FontWeight', 'normal');


% 普通英文使用 Times New Roman
ylabel( ...
    axMain, ...
    'Platform revenue', ...
    'Interpreter', 'tex', ...
    'FontName', 'Times New Roman', ...
    'FontSize', 16, ...
    'FontWeight', 'normal');


%% =========================================================
% 22. 可选主图标题
% ==========================================================

if showMainTitle

    title( ...
        axMain, ...
        'Platform revenue under different governance regimes', ...
        'Interpreter', 'tex', ...
        'FontName', 'Times New Roman', ...
        'FontSize', 16, ...
        'FontWeight', 'normal');

end


%% =========================================================
% 23. 设置主图图例
% ==========================================================

legendMain = legend( ...
    axMain, ...
    [ ...
        lineFree, ...
        lineSharing, ...
        lineMembership ...
    ], ...
    { ...
        'Free regime', ...
        'Revenue-sharing regime', ...
        'Membership regime' ...
    }, ...
    'Interpreter', 'tex', ...
    'Location', 'northwest', ...
    'FontName', 'Times New Roman', ...
    'FontSize', 14, ...
    'FontWeight', 'normal', ...
    'Box', 'off');


set( ...
    legendMain, ...
    'AutoUpdate', 'off', ...
    'Visible', 'on');


try

    legendMain.ItemTokenSize = [24, 10];

catch
end


%% =========================================================
% 24. 设置主图格式
% ==========================================================

if showMainGrid

    grid(axMain, 'on');


    axMain.GridColor = ...
        [0.85, 0.85, 0.85];


    axMain.GridAlpha = 0.30;


    axMain.GridLineStyle = '-';

else

    grid(axMain, 'off');

end


box(axMain, 'on');


set( ...
    axMain, ...
    'FontName', 'Times New Roman', ...
    'FontSize', 16, ...
    'FontWeight', 'normal', ...
    'LineWidth', 1.1, ...
    'TickDir', 'in', ...
    'TickLength', [0.015, 0.015], ...
    'Layer', 'top');


%% ========================================================================
% 嵌入式小窗口：免费制与会员制的局部放大
% ========================================================================

%% =========================================================
% 25. 确定小窗口时间范围
% ==========================================================

zoomStartIndex = round( ...
    zoomStartFraction * ...
    (numPoints - 1)) + 1;


zoomStartIndex = max( ...
    zoomStartIndex, ...
    1);


zoomIndex = ...
    zoomStartIndex:plotEvery:numPoints;


if zoomIndex(end) ~= numPoints

    zoomIndex = [ ...
        zoomIndex, ...
        numPoints];

end


zoomTime = ...
    timeSteps(zoomIndex);


zoomFree = ...
    freeRevenue(zoomIndex);


zoomMembership = ...
    membershipRevenue(zoomIndex);


%% =========================================================
% 26. 创建嵌入式坐标轴
% ==========================================================

axInset = axes( ...
    'Parent', fig, ...
    'Position', insetAxesPosition, ...
    'Color', 'w', ...
    'Box', 'on');


hold(axInset, 'on');


%% =========================================================
% 27. 绘制免费制与会员制之间的差异阴影
% ==========================================================

fillX = [ ...
    zoomTime; ...
    flipud(zoomTime)];


fillY = [ ...
    zoomMembership; ...
    flipud(zoomFree)];


fill( ...
    axInset, ...
    fillX, ...
    fillY, ...
    differenceColor, ...
    'FaceAlpha', 0.18, ...
    'EdgeColor', 'none', ...
    'HandleVisibility', 'off');


%% =========================================================
% 28. 绘制免费制与会员制曲线
% ==========================================================

lineFreeInset = plot( ...
    axInset, ...
    zoomTime, ...
    zoomFree, ...
    '-', ...
    'LineWidth', 2.0, ...
    'Color', freeColor);


lineMembershipInset = plot( ...
    axInset, ...
    zoomTime, ...
    zoomMembership, ...
    '-', ...
    'LineWidth', 2.0, ...
    'Color', membershipColor);


hold(axInset, 'off');


%% =========================================================
% 29. 设置小窗口横坐标范围
% ==========================================================

xlim(axInset, [ ...
    timeSteps(zoomStartIndex), ...
    timeSteps(end)]);


%% =========================================================
% 30. 设置小窗口纵坐标范围
% ==========================================================

zoomMinimum = min([ ...
    freeRevenue(zoomStartIndex:end); ...
    membershipRevenue(zoomStartIndex:end)]);


zoomMaximum = max([ ...
    freeRevenue(zoomStartIndex:end); ...
    membershipRevenue(zoomStartIndex:end)]);


zoomRange = ...
    zoomMaximum - zoomMinimum;


if zoomRange <= 0

    zoomPadding = 1;

else

    % 上下各保留约12%的留白
    zoomPadding = max( ...
        0.10, ...
        0.12 * zoomRange);

end


ylim(axInset, [ ...
    zoomMinimum - zoomPadding, ...
    zoomMaximum + zoomPadding]);


%% =========================================================
% 31. 设置小窗口标题
% ==========================================================

if showInsetTitle

    title( ...
        axInset, ...
        'Free vs. Membership', ...
        'Interpreter', 'tex', ...
        'FontName', 'Times New Roman', ...
        'FontSize', 16, ...
        'FontWeight', 'normal');

end


%% =========================================================
% 32. 设置小窗口坐标轴名称
% ==========================================================

% 数学变量 t 使用 LaTeX
xlabel( ...
    axInset, ...
    '$t$', ...
    'Interpreter', 'latex', ...
    'FontSize', 16, ...
    'FontWeight', 'normal');


% 普通英文使用 Times New Roman
ylabel( ...
    axInset, ...
    'Revenue', ...
    'Interpreter', 'tex', ...
    'FontName', 'Times New Roman', ...
    'FontSize', 16, ...
    'FontWeight', 'normal');


%% =========================================================
% 33. 设置小窗口图例
% ==========================================================

legendInset = legend( ...
    axInset, ...
    [ ...
        lineFreeInset, ...
        lineMembershipInset ...
    ], ...
    { ...
        'Free', ...
        'Membership' ...
    }, ...
    'Interpreter', 'tex', ...
    'Location', 'best', ...
    'FontName', 'Times New Roman', ...
    'FontSize', 12, ...
    'FontWeight', 'normal', ...
    'Box', 'off');


set( ...
    legendInset, ...
    'AutoUpdate', 'off', ...
    'Visible', 'on');


try

    legendInset.ItemTokenSize = [16, 8];

catch
end


%% =========================================================
% 34. 设置小窗口格式
% ==========================================================

if showInsetGrid

    grid(axInset, 'on');


    axInset.GridColor = ...
        [0.82, 0.82, 0.82];


    axInset.GridAlpha = 0.35;


    axInset.GridLineStyle = '-';

else

    grid(axInset, 'off');

end


set( ...
    axInset, ...
    'FontName', 'Times New Roman', ...
    'FontSize', 10, ...
    'FontWeight', 'normal', ...
    'LineWidth', 1.0, ...
    'TickDir', 'in', ...
    'TickLength', [0.020, 0.020], ...
    'Layer', 'top');


%% =========================================================
% 35. 保证小窗口位于最上层
% ==========================================================

uistack(axInset, 'top');


%% =========================================================
% 36. 调整图形边距
% ==========================================================

drawnow;


set( ...
    axMain, ...
    'LooseInset', ...
    max(get(axMain, 'TightInset'), 0.02));


%% =========================================================
% 37. 可选：保存图片
% ==========================================================

if saveFigure

    outputImage = fullfile( ...
        dataFolder, ...
        'platform_revenue_comparison_with_inset.png');


    exportgraphics( ...
        fig, ...
        outputImage, ...
        'Resolution', ...
        exportResolution);


    fprintf( ...
        '\n图片已保存至：\n%s\n', ...
        outputImage);

end


%% ========================================================================
% 辅助函数1：
% 自动查找平台收益 Excel 文件
% ========================================================================

function xlsxFile = findRevenueWorkbook( ...
    dataFolder, ...
    sheetName, ...
    headerRow)

    xlsxFiles = dir( ...
        fullfile(dataFolder, '*.xlsx'));


    if isempty(xlsxFiles)

        error(['当前文件夹中没有找到.xlsx文件。', ...
            '请将数据文件与m文件放在同一个文件夹中。']);

    end


    % 排除 Excel 临时文件
    fileNames = {xlsxFiles.name};


    temporaryFlag = ...
        startsWith(fileNames, '~$');


    xlsxFiles = ...
        xlsxFiles(~temporaryFlag);


    if isempty(xlsxFiles)

        error('没有找到有效的Excel文件。');

    end


    matchedFiles = strings(0, 1);


    for fileIdx = 1:numel(xlsxFiles)

        currentFile = fullfile( ...
            dataFolder, ...
            xlsxFiles(fileIdx).name);


        try

            preview = readcell( ...
                currentFile, ...
                'Sheet', sheetName, ...
                'Range', 'A1:Z5');

        catch

            continue;

        end


        if size(preview, 1) < headerRow

            continue;

        end


        previewText = strings( ...
            1, ...
            size(preview, 2));


        for colIdx = 1:size(preview, 2)

            previewText(colIdx) = ...
                safeCellToString( ...
                    preview{headerRow, colIdx});

        end


        hasFree = any( ...
            contains(previewText, "免费"));


        hasSharing = any( ...
            contains(previewText, "分成"));


        hasMembership = any( ...
            contains(previewText, "会员"));


        if hasFree && ...
                hasSharing && ...
                hasMembership

            matchedFiles(end + 1, 1) = ...
                string(currentFile);

        end

    end


    if isempty(matchedFiles)

        error(['没有找到同时包含"免费、分成、会员"', ...
            '三种表头的Excel文件。']);

    end


    if numel(matchedFiles) > 1

        warning(['检测到多个匹配的数据文件，', ...
            '程序将使用第一个文件：\n%s'], ...
            matchedFiles(1));

    end


    xlsxFile = char(matchedFiles(1));

end


%% ========================================================================
% 辅助函数2：
% 将单列 cell 转换为 double
% ========================================================================

function numericColumn = cellColumnToDouble(cellColumn)

    numRows = numel(cellColumn);


    numericColumn = nan(numRows, 1);


    for rowIdx = 1:numRows

        value = cellColumn{rowIdx};


        if isempty(value)

            numericColumn(rowIdx) = NaN;


        elseif isnumeric(value)

            if isscalar(value)

                numericColumn(rowIdx) = ...
                    double(value);

            end


        elseif ischar(value)

            convertedValue = ...
                str2double(strtrim(value));


            if isscalar(convertedValue) && ...
                    ~isnan(convertedValue)

                numericColumn(rowIdx) = ...
                    convertedValue;

            end


        elseif isstring(value)

            if ~all(ismissing(value(:)))

                convertedValue = ...
                    str2double(strtrim(value));


                if isscalar(convertedValue) && ...
                        ~isnan(convertedValue)

                    numericColumn(rowIdx) = ...
                        convertedValue;

                end

            end


        else

            try

                convertedValue = ...
                    str2double(string(value));


                if isscalar(convertedValue) && ...
                        ~isnan(convertedValue)

                    numericColumn(rowIdx) = ...
                        convertedValue;

                end


            catch

                numericColumn(rowIdx) = NaN;

            end

        end

    end

end


%% ========================================================================
% 辅助函数3：
% 删除向量末尾的 NaN
% ========================================================================

function outputVector = trimTrailingNaN(inputVector)

    lastValidIndex = find( ...
        ~isnan(inputVector), ...
        1, ...
        'last');


    if isempty(lastValidIndex)

        outputVector = [];

    else

        outputVector = ...
            inputVector(1:lastValidIndex);

    end

end


%% ========================================================================
% 辅助函数4：
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