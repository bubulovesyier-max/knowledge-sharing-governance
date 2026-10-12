%% fig_steady_state_r_BC.m
% 功能：
% 读取Excel数据
% 计算最后10%时间稳态比例
% 绘制会员制收费模式下s对 rho_B* 和 rho_C* 的影响
%
% 统一绘图格式：
% 1. 数学符号统一使用 LaTeX；
% 2. 所有文字均不加粗；
% 3. 普通文字和坐标刻度使用 Times New Roman；
% 4. 保持原有字体大小不变；
% 5. 保持原有颜色、线型和 Marker 不变。

clear;
clc;
close all;


%% ===============================
% 1. 读取Excel
% ===============================

thisFile = mfilename('fullpath');

if isempty(thisFile)
    dataFolder = pwd;
else
    dataFolder = fileparts(thisFile);
end


xlsxFiles = dir(fullfile(dataFolder,'*.xlsx'));

if isempty(xlsxFiles)
    error('当前文件夹没有Excel文件');
end


xlsxFile = fullfile(dataFolder,xlsxFiles(1).name);

fprintf('读取文件：\n%s\n',xlsxFile);


raw = readcell(xlsxFile);


[nRows,nCols] = size(raw);



%% ===============================
% 2. Excel格式设置
% ===============================

paramRow = 2;
strategyRow = 3;
dataStartRow = 4;



%% ===============================
% 3. 识别参数列
% ===============================

headerStr = strings(1,nCols);

for i = 1:nCols
    headerStr(i) = string(raw{paramRow,i});
end


paramCols = find(contains(headerStr,"r="));


if isempty(paramCols)

    strategyStr = strings(1,nCols);

    for i = 1:nCols
        strategyStr(i) = string(raw{strategyRow,i});
    end

    paramCols = find(strcmpi(strategyStr,"A"));

end


numParams = length(paramCols);


fprintf('识别参数数量：%d\n',numParams);



%% ===============================
% 4. 提取参数值
% ===============================

paramValues = zeros(numParams,1);


for k = 1:numParams

    txt = char(headerStr(paramCols(k)));

    value = regexp(txt,...
        '[-+]?\d*\.?\d+',...
        'match');

    if ~isempty(value)
        paramValues(k) = str2double(value{1});
    else
        paramValues(k) = k;
    end

end



%% ===============================
% 5. 读取时间序列
% ===============================

steadyRho = zeros(numParams,4);


for k = 1:numParams


    c0 = paramCols(k);


    dataCols = c0:c0+3;


    dataCell = raw(dataStartRow:end,dataCols);


    data = zeros(size(dataCell));


    for i = 1:size(dataCell,1)

        for j = 1:4

            data(i,j) = str2double(string(dataCell{i,j}));

        end

    end


    % 删除空值
    data = data(all(~isnan(data),2),:);


    % 最后10%
    n = size(data,1);

    startIndex = max(1,...
        floor(0.9*n));


    steadyData = data(startIndex:end,:);


    steadyRho(k,:) = mean(steadyData,1);


end



%% ===============================
% 6. 排序
% ===============================

[paramValues,order] = sort(paramValues);

steadyRho = steadyRho(order,:);



%% ===============================
% 7. 绘图
% ===============================

figure(...
    'Color','w',...
    'Units','centimeters',...
    'Position',[5 5 15 12]);

ax = gca;

hold on;



% ===============================
% 策略B
% ===============================

plot(ax,...
    paramValues,...
    steadyRho(:,2),...
    '-s',...
    'LineWidth',2,...
    'MarkerSize',7,...
    'MarkerFaceColor','w',...
    'Color',[0 0.4470 0.7410]);



% ===============================
% 策略C
% ===============================

plot(ax,...
    paramValues,...
    steadyRho(:,3),...
    '-^',...
    'LineWidth',2,...
    'MarkerSize',7,...
    'MarkerFaceColor','w',...
    'Color',[0.8500 0.3250 0.0980]);



hold off;



%% ===============================
% 8. 坐标轴设置
% ===============================

% ===============================
% 横轴
% 数学变量使用 LaTeX
% 字号保持 18
% 不加粗
% ===============================

xlabel(...
    '$s$',...
    'Interpreter','latex',...
    'FontSize',18,...
    'FontWeight','normal');


% ===============================
% 纵轴
% 普通英文使用 Times New Roman
% 字号保持 18
% 不加粗
% ===============================

ylabel(...
    'Steady-state strategy proportion',...
    'Interpreter','latex',...
    'FontName','Times New Roman',...
    'FontSize',17,...
    'FontWeight','normal');


% 原有纵坐标范围保持不变
ylim([0.46 0.54]);


% 原有横坐标刻度保持不变
xticks(paramValues);


grid off;

box on;



%% ===============================
% 图例
% 数学符号统一使用 LaTeX
% 字号保持 18
% 不加粗
% ===============================

lgd = legend(...
    {'$\rho_B^{*}$','$\rho_C^{*}$'},...
    'Interpreter','latex',...
    'Location','best',...
    'FontSize',18,...
    'FontWeight','normal',...
    'Box','on');


% 防止后续绘图操作改变图例
set(...
    lgd,...
    'AutoUpdate','off',...
    'Visible','on');



%% ===============================
% 坐标轴字体统一
% Times New Roman
% 字号保持 18
% 不加粗
% ===============================

set(...
    ax,...
    'FontName','Times New Roman',...
    'FontSize',18,...
    'FontWeight','normal',...
    'LineWidth',1.4,...
    'TickDir','in',...
    'TickLength',[0.015 0.015],...
    'Layer','top');


% 自动调整边距
drawnow;

set(...
    ax,...
    'LooseInset',...
    max(get(ax,'TightInset'),0.02));



%% ===============================
% 9. 输出结果
% ===============================

ResultTable = table(...
    paramValues,...
    steadyRho(:,2),...
    steadyRho(:,3),...
    'VariableNames',...
    {'r','rhoB','rhoC'});


disp('稳态结果：');

disp(ResultTable);