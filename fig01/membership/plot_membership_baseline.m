%% Read strategy evolution data from Excel and plot figures
% 读取 Excel 中的策略比例数据并画图
%
% 使用方式：
% 1. 将本 m 文件与 Excel 文件放在同一个文件夹下。
% 2. 如果文件夹中只有一个 .xlsx 文件，本代码会自动读取它。
% 3. 如果文件夹中有多个 .xlsx 文件，请手动修改 excelFileName。
%
% 当前 Excel 数据格式：
% 第1行：模式名称和参数说明
% 第2行：变量名 A, B, C, D
% 第3行及以后：每个时间步下 A, B, C, D 的策略比例
%
% 统一绘图格式：
% 1. 数学符号统一使用 LaTeX；
% 2. 普通英文和坐标刻度使用 Times New Roman；
% 3. 所有文字均不加粗；
% 4. 保持原有字体大小 18 不变；
% 5. 保持原有颜色和线宽不变。

clear;
clc;
close all;


%% =========================================================
% 1. 定位 Excel 文件
% ==========================================================

% 获取当前 m 文件所在文件夹
scriptDir = fileparts(mfilename('fullpath'));

% 如果在命令窗口直接运行分段代码，
% mfilename 可能为空，此时使用当前工作路径
if isempty(scriptDir)
    scriptDir = pwd;
end


% 自动寻找同一文件夹下的 xlsx 文件
xlsxFiles = dir(fullfile(scriptDir, '*.xlsx'));


if isempty(xlsxFiles)

    error(['当前文件夹下没有找到 .xlsx 文件。', ...
        '请将 Excel 文件和本代码放在同一个文件夹下。']);

end


% 如果文件夹下只有一个 xlsx 文件，自动读取该文件
% 如果有多个 xlsx 文件，可以在这里手动指定文件名
if numel(xlsxFiles) == 1

    excelFileName = xlsxFiles(1).name;

else

    excelFileName = xlsxFiles(1).name;

    warning(['当前文件夹下有多个 .xlsx 文件，代码默认读取：%s。' ...
             '如需读取其他文件，请修改 excelFileName。'], ...
             excelFileName);

end


excelFile = fullfile(scriptDir, excelFileName);


%% =========================================================
% 2. 读取 Sheet1 中的策略比例数据
% ==========================================================

sheetName = 'Sheet1';


% 读取原始单元格，用于获取标题和参数说明
rawCell = readcell( ...
    excelFile, ...
    'Sheet', sheetName);


% 第1行通常是模式名称和参数说明
modeTitle = string(rawCell{1, 1});


if size(rawCell, 2) >= 2 && ...
        ~ismissing(string(rawCell{1, 2}))

    paramText = string(rawCell{1, 2});

else

    paramText = "";

end


% 直接读取 A:D 列的数值矩阵
% 第1行和第2行是文字，readmatrix 会将其读成 NaN
rawData = readmatrix( ...
    excelFile, ...
    'Sheet', sheetName, ...
    'Range', 'A:D');


% 从第3行开始是四类策略比例
strategyData = rawData(3:end, 1:4);


% 删除完全为空的行
strategyData = ...
    strategyData(~all(isnan(strategyData), 2), :);


% 如果存在个别空值，用前一行填充；
% 如果第一行为空，则填0
strategyData = ...
    fillmissing(strategyData, 'previous');

strategyData = ...
    fillmissing(strategyData, 'constant', 0);


% 分别取出四类策略比例
rhoA = strategyData(:, 1);

rhoB = strategyData(:, 2);

rhoC = strategyData(:, 3);

rhoD = strategyData(:, 4);


% 构造时间步
% 第1个数据点对应初始状态 t = 0
numSteps = size(strategyData, 1);

updateStep = (0:numSteps-1)';


%% =========================================================
% 3. 设置四类策略颜色
% ==========================================================

% 保持原有颜色不变

strategyColors = [
    0.4940, 0.1840, 0.5560;   % A：紫色
    0.8500, 0.3250, 0.0980;   % B：橙红色
    0.0000, 0.4470, 0.7410;   % C：蓝色
    0.4660, 0.6740, 0.1880    % D：绿色
];


%% =========================================================
% 4. 四类策略比例演化线图
% ==========================================================

figure( ...
    'Color', 'w', ...
    'Position', [100, 100, 620, 420]);


ax = gca;


% A：紫色
plot( ...
    ax, ...
    updateStep, ...
    rhoA, ...
    'LineWidth', 2, ...
    'Color', strategyColors(1, :));


hold(ax, 'on');


% B：橙红色
plot( ...
    ax, ...
    updateStep, ...
    rhoB, ...
    'LineWidth', 2, ...
    'Color', strategyColors(2, :));


% C：蓝色
plot( ...
    ax, ...
    updateStep, ...
    rhoC, ...
    'LineWidth', 2, ...
    'Color', strategyColors(3, :));


% D：绿色
plot( ...
    ax, ...
    updateStep, ...
    rhoD, ...
    'LineWidth', 2, ...
    'Color', strategyColors(4, :));


hold(ax, 'off');


%% =========================================================
% 5. 坐标范围
% ==========================================================

xlim(ax, [0, updateStep(end)]);

ylim(ax, [0, 1]);


%% =========================================================
% 6. 坐标轴标签
% ==========================================================

% 横轴：
% 数学变量 t 使用 LaTeX
% 字号保持 18
% 不加粗

xlabel( ...
    ax, ...
    '$t$', ...
    'Interpreter', 'latex', ...
    'FontSize', 18, ...
    'FontWeight', 'normal');


% 纵轴：
% 普通英文使用 Times New Roman
% 字号保持 18
% 不加粗

ylabel( ...
    ax, ...
    'Strategy proportion', ...
    'Interpreter', 'tex', ...
    'FontName', 'Times New Roman', ...
    'FontSize', 18, ...
    'FontWeight', 'normal');


%% =========================================================
% 7. 标题
% ==========================================================

% 普通英文使用 Times New Roman
% 字号保持 18
% 不加粗

title( ...
    ax, ...
    'Membership regime', ...
    'Interpreter', 'tex', ...
    'FontName', 'Times New Roman', ...
    'FontSize', 18, ...
    'FontWeight', 'normal');


%% =========================================================
% 8. 图例
% ==========================================================

% A、B、C、D 作为策略符号
% 使用 LaTeX
% 字号保持 18
% 不加粗

lgd = legend( ...
    ax, ...
    {'$A$', '$B$', '$C$', '$D$'}, ...
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
% 9. 坐标轴格式
% ==========================================================

% 坐标刻度：
% Times New Roman
% 字号保持 18
% 不加粗

set( ...
    ax, ...
    'FontName', 'Times New Roman', ...
    'FontSize', 18, ...
    'FontWeight', 'normal', ...
    'LineWidth', 1.4, ...
    'Box', 'on', ...
    'TickDir', 'in', ...
    'Layer', 'top');


% 不显示网格
grid(ax, 'off');