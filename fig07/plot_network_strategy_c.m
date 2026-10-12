%% =========================================================
% 不同网络结构下策略 C 稳态比例的棒棒图
%
% Governance regimes:
% Free / Revenue-sharing / Membership
%
% Network structures:
% Regular / WS / BA
%
% 统一绘图格式：
% 1. 普通英文和坐标刻度使用 Times New Roman；
% 2. 所有文字均不加粗；
% 3. 保持原有字号：
%    坐标轴名称 16；
%    坐标刻度 14；
%    图例 14；
%    数值标签 14；
% 4. 三种网络的颜色和 marker 保持不变；
% 5. 不显示网格；
% 6. 坐标轴刻度朝内；
% 7. 坐标轴线宽统一为 1.4；
% 8. 图窗尺寸统一为 620 × 420。
%% =========================================================

clear;
clc;
close all;


%% =========================================================
% 1. 数据
% ==========================================================

% 行：三种治理制度
% 列：Regular, WS, BA

C = [ ...
    0.8156, 0.8150, 0.7992;   % Free
    0.0443, 0.0401, 0.1096;   % Revenue-sharing
    0.5317, 0.5373, 0.5106];  % Membership


modeNames = { ...
    'Free', ...
    'Revenue-sharing', ...
    'Membership'};


networkNames = { ...
    'Regular', ...
    'WS', ...
    'BA'};


%% =========================================================
% 2. 基本设置
% ==========================================================

nModes = size(C, 1);

nNetworks = size(C, 2);


% 三种治理制度中心位置
% 保持三个治理制度之间的紧凑间距

xCenter = [0.8, 1.3, 1.8];


% 同一治理制度内 Regular / WS / BA 的横向距离

offset = [-0.15, 0, 0.15];


% 三种网络对应不同 marker

markers = { ...
    'o', ...   % Regular
    's', ...   % WS
    '^'};      % BA


% 三种网络颜色
% 保持原有颜色不变

colors = [ ...
    0.20, 0.45, 0.75;   % Regular：蓝色
    0.90, 0.50, 0.20;   % WS：橙色
    0.35, 0.65, 0.40];  % BA：绿色


%% =========================================================
% 3. 创建图形
% ==========================================================

fig = figure( ...
    'Color', 'w', ...
    'Position', [100, 100, 620, 420], ...
    'Name', 'Network robustness of strategy C', ...
    'NumberTitle', 'off');


ax = axes( ...
    'Parent', fig);


hold(ax, 'on');


legendHandle = ...
    gobjects(nNetworks, 1);


%% =========================================================
% 4. 绘制棒棒图
% ==========================================================

for j = 1:nNetworks

    for i = 1:nModes

        % 当前点横坐标
        x = ...
            xCenter(i) + offset(j);


        % 当前稳态比例
        y = ...
            C(i, j);


        % 竖直棒
        plot( ...
            ax, ...
            [x, x], ...
            [0, y], ...
            '-', ...
            'Color', colors(j, :), ...
            'LineWidth', 2.6);


        % 棒顶部 marker
        h = plot( ...
            ax, ...
            x, ...
            y, ...
            markers{j}, ...
            'MarkerSize', 8, ...
            'MarkerFaceColor', colors(j, :), ...
            'MarkerEdgeColor', colors(j, :), ...
            'LineWidth', 1.8);


        % 图例中每种网络只记录一次
        if i == 1

            legendHandle(j) = h;

        end

    end

end


%% =========================================================
% 5. 添加数值标签
% ==========================================================

for j = 1:nNetworks

    for i = 1:nModes

        x = ...
            xCenter(i) + offset(j);


        y = ...
            C(i, j);


        text( ...
            ax, ...
            x, ...
            y + 0.022, ...
            sprintf('%.4f', y), ...
            'HorizontalAlignment', 'center', ...
            'VerticalAlignment', 'bottom', ...
            'Interpreter', 'tex', ...
            'FontName', 'Times New Roman', ...
            'FontSize', 12, ...
            'FontWeight', 'normal', ...
            'Color', colors(j, :));

    end

end


%% =========================================================
% 6. 坐标轴范围与刻度
% ==========================================================

% 横轴范围与治理制度间距相匹配

xlim(ax, [0.55, 2.10]);


% 纵轴范围

ylim(ax, [0, 1.05]);


% 横轴刻度位置

xticks(ax, xCenter);


% 横轴刻度名称

xticklabels(ax, modeNames);


% 保持横轴刻度标签水平

xtickangle(ax, 0);


% 纵轴刻度

yticks(ax, 0:0.2:1.0);


%% =========================================================
% 7. 坐标轴名称
% ==========================================================

% 横轴不需要额外名称

xlabel( ...
    ax, ...
    '', ...
    'Interpreter', 'tex', ...
    'FontName', 'Times New Roman', ...
    'FontSize', 16, ...
    'FontWeight', 'normal');


% 纵轴普通英文使用 Times New Roman

ylabel( ...
    ax, ...
    'Steady-state proportion of strategy C', ...
    'Interpreter', 'tex', ...
    'FontName', 'Times New Roman', ...
    'FontSize', 16, ...
    'FontWeight', 'normal');


%% =========================================================
% 8. 图例
% ==========================================================

lgd = legend( ...
    ax, ...
    legendHandle, ...
    networkNames, ...
    'Location', 'northoutside', ...
    'Orientation', 'horizontal', ...
    'Interpreter', 'tex', ...
    'FontName', 'Times New Roman', ...
    'FontSize', 16, ...
    'FontWeight', 'normal', ...
    'Box', 'off');


% 防止后续操作自动改变图例

set( ...
    lgd, ...
    'AutoUpdate', 'off', ...
    'Visible', 'on');


%% =========================================================
% 9. 坐标轴统一格式
% ==========================================================

% 不显示网格

grid(ax, 'off');


% 显示四周坐标轴边框

box(ax, 'on');


% 坐标刻度使用 Times New Roman
% 不加粗
% 刻度朝内

set( ...
    ax, ...
    'FontName', 'Times New Roman', ...
    'FontSize', 16, ...
    'FontWeight', 'normal', ...
    'LineWidth', 1.4, ...
    'TickDir', 'in', ...
    'TickLength', [0.015, 0.015], ...
    'Layer', 'top');


%% =========================================================
% 10. 调整绘图区
% ==========================================================

% 给顶部图例留出足够空间

ax.Position = ...
    [0.13, 0.15, 0.82, 0.70];


drawnow;


%% =========================================================
% 11. 完成绘图
% ==========================================================

hold(ax, 'off');


%% =========================================================
% 12. 输出高清图片
% ==========================================================

% PNG

exportgraphics( ...
    fig, ...
    'Network_robustness_strategy_C_color.png', ...
    'Resolution', 600);


% 矢量 PDF

exportgraphics( ...
    fig, ...
    'Network_robustness_strategy_C_color.pdf', ...
    'ContentType', 'vector');