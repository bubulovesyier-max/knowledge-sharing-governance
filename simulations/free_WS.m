%% Free mode simulation on a Watts-Strogatz small-world network
% 免费模式下的知识共享演化博弈仿真程序：WS小世界网络版本
%
% 相对于原规则网络版本，本代码只改变网络结构：
% 1. 网络由二维Moore规则网络改为Watts-Strogatz小世界网络；
% 2. 节点数保持 N = 2500；
% 3. 目标平均度保持为 8；
% 4. 初始环形规则网络中每个节点连接左右各4个邻居，因此平均度恰为8；
% 5. 以概率 wsBeta 对"顺时针"的4条边进行随机重连，保持总边数不变，
%    因而重连后的WS网络平均度仍严格为8，但节点度数允许存在异质性；
% 6. 在WS网络中，参与者i参与"以自身及其所有邻居为中心"的局部公共品博弈，
%    因为重连后节点度数不再全部等于8，所以个体效用取其实际参与局部群组的平均值。
%
% 策略编码：
% A = 1: supply only         只供给知识，不享用知识
% B = 2: supply and consume  既供给知识，也享用知识
% C = 3: consume only        只享用知识，不供给知识
% D = 4: inactive            不供给也不享用，处于低活跃状态
%
% 本代码采用随机异步更新方式：
% 每一个时间步只随机抽取一个参与者进行一次费米规则更新。
% 每次更新后记录四类策略比例和平台总收益。

clear;
clc;
close all;

%% 1. 基准参数设置
params.c = 1.00;         % c：知识供给成本
params.u = 2.00;         % u：知识享用的最大潜在效用
params.alpha = 0.25;     % alpha：知识吸收效率
params.hF = 0.25;        % hF：免费模式下知识供给者的非货币收益强度
params.kappa = 0.20;     % kappa：费米更新规则噪声强度
params.sigma = 0.15;     % sigma：平台间接收益能力系数

N = 2500;                % 参与者总数，与原50×50规则网络一致
T = 80000;               % 异步更新时间步数

% Watts-Strogatz网络参数
targetMeanDegree = 8;    % 目标平均度：8
wsBeta = 0.20;           % 重连概率。0为规则环形网络，1为高度随机化网络；0.1常用于小世界情景

nReplicates = 10;        % 独立重复仿真次数
masterSeed = 20260710;   % 主随机种子
initialProb = [0.25, 0.25, 0.25, 0.25];

% 基本检查
if mod(targetMeanDegree, 2) ~= 0
    error('WS网络的初始规则度K必须为偶数。');
end
if targetMeanDegree >= N
    error('targetMeanDegree必须小于N。');
end
if wsBeta < 0 || wsBeta > 1
    error('wsBeta必须位于[0,1]。');
end

%% 2. 输出文件夹设置
scriptDir = fileparts(mfilename('fullpath'));
outputDir = fullfile(scriptDir, 'results_free_WS_K8_beta0p20');

if ~exist(outputDir, 'dir')
    mkdir(outputDir);
end

%% 3. 多次独立仿真
allHistory = zeros(T + 1, 4, nReplicates);
allRevenueHistory = zeros(T + 1, nReplicates);
finalStrategies = zeros(N, nReplicates, 'uint8');

% 保存每次WS网络的基本统计量
meanDegreeReplicates = zeros(nReplicates, 1);
minDegreeReplicates = zeros(nReplicates, 1);
maxDegreeReplicates = zeros(nReplicates, 1);

for rIndex = 1:nReplicates

    % 将网络随机性与策略演化随机性分开，便于复现。
    % 如果以后做分成制、会员制WS网络，建议保持同样的networkSeed定义，
    % 这样同一个rIndex下三种治理模式使用相同的WS网络实现。
    networkSeed = masterSeed + 100000 + rIndex - 1;
    runSeed = masterSeed + rIndex - 1;

    % 生成一个WS小世界网络。
    [neighborList, degreeVector] = generateWSNetwork( ...
        N, targetMeanDegree, wsBeta, networkSeed);

    meanDegreeReplicates(rIndex) = mean(degreeVector);
    minDegreeReplicates(rIndex) = min(degreeVector);
    maxDegreeReplicates(rIndex) = max(degreeVector);

    % WS重连保持总边数不变，因此平均度应严格等于目标值8。
    if abs(meanDegreeReplicates(rIndex) - targetMeanDegree) > 1e-12
        error('第%d次重复的WS网络平均度不是8，请检查网络生成函数。', rIndex);
    end

    % 运行一次免费模式异步仿真
    [allHistory(:, :, rIndex), allRevenueHistory(:, rIndex), ...
        finalStrategy] = simulateFreeModeAsyncWS( ...
        params, N, T, initialProb, runSeed, neighborList);

    finalStrategies(:, rIndex) = uint8(finalStrategy);

    fprintf('Replicate %d/%d completed: mean degree = %.4f, min = %d, max = %d\n', ...
        rIndex, nReplicates, meanDegreeReplicates(rIndex), ...
        minDegreeReplicates(rIndex), maxDegreeReplicates(rIndex));
end

%% 4. 计算均值、标准误和派生指标
meanHistory = mean(allHistory, 3);
seHistory = std(allHistory, 0, 3) / sqrt(nReplicates);

meanRevenueHistory = mean(allRevenueHistory, 2);
seRevenueHistory = std(allRevenueHistory, 0, 2) / sqrt(nReplicates);

updateStep = (0:T)';

supplyRate = meanHistory(:, 1) + meanHistory(:, 2);
consumeRate = meanHistory(:, 2) + meanHistory(:, 3);

%% 5. 保存数据表
simulationData = table(updateStep, ...
    meanHistory(:, 1), meanHistory(:, 2), ...
    meanHistory(:, 3), meanHistory(:, 4), ...
    seHistory(:, 1), seHistory(:, 2), ...
    seHistory(:, 3), seHistory(:, 4), ...
    supplyRate, consumeRate, ...
    meanRevenueHistory, seRevenueHistory, ...
    'VariableNames', {'UpdateStep', ...
    'A', 'B', 'C', 'D', ...
    'SE_A', 'SE_B', 'SE_C', 'SE_D', ...
    'SupplyRate', 'ConsumeRate', ...
    'PlatformRevenue', 'SE_PlatformRevenue'});

writetable(simulationData, ...
    fullfile(outputDir, 'free_mode_WS_K8_async_data.csv'));

networkSummary = table((1:nReplicates)', ...
    meanDegreeReplicates, minDegreeReplicates, maxDegreeReplicates, ...
    'VariableNames', {'Replicate', 'MeanDegree', 'MinDegree', 'MaxDegree'});

writetable(networkSummary, ...
    fullfile(outputDir, 'WS_network_degree_summary.csv'));

save(fullfile(outputDir, 'free_mode_WS_K8_async_data.mat'), ...
    'params', 'N', 'T', 'targetMeanDegree', 'wsBeta', ...
    'nReplicates', 'masterSeed', 'initialProb', ...
    'simulationData', 'networkSummary', ...
    'allHistory', 'allRevenueHistory', ...
    'meanHistory', 'seHistory', ...
    'meanRevenueHistory', 'seRevenueHistory', ...
    'finalStrategies', ...
    'meanDegreeReplicates', 'minDegreeReplicates', 'maxDegreeReplicates');

%% 6. 图1：四类策略比例演化图
figure('Visible', 'off', 'Color', 'w', 'Position', [100, 100, 840, 540]);

plot(updateStep, meanHistory(:, 1), 'LineWidth', 1.8);
hold on;
plot(updateStep, meanHistory(:, 2), 'LineWidth', 1.8);
plot(updateStep, meanHistory(:, 3), 'LineWidth', 1.8);
plot(updateStep, meanHistory(:, 4), 'LineWidth', 1.8);
hold off;

grid on;
box on;
xlim([0, T]);
ylim([0, 1]);

xlabel('Asynchronous update step');
ylabel('Strategy proportion');
title(sprintf('Free mode on WS network: K = %d, beta = %.2f', ...
    targetMeanDegree, wsBeta));

legend({'A: supply only', ...
    'B: supply and consume', ...
    'C: consume only', ...
    'D: inactive'}, ...
    'Location', 'best');

exportgraphics(gcf, fullfile(outputDir, ...
    'free_mode_WS_K8_strategy_trajectory.png'), 'Resolution', 300);

close(gcf);

%% 7. 图2：平台总收益演化图
figure('Visible', 'off', 'Color', 'w', 'Position', [100, 100, 840, 540]);

plot(updateStep, meanRevenueHistory, 'LineWidth', 1.8);
grid on;
box on;
xlim([0, T]);

xlabel('Asynchronous update step');
ylabel('Platform revenue');
title(sprintf('Free mode platform revenue on WS network: K = %d, beta = %.2f', ...
    targetMeanDegree, wsBeta));

exportgraphics(gcf, fullfile(outputDir, ...
    'free_mode_WS_K8_platform_revenue.png'), 'Resolution', 300);

close(gcf);

%% 8. 命令窗口输出最终结果
fprintf('\nFree mode WS-network asynchronous simulation completed.\n');
fprintf('WS parameters: N = %d, target mean degree = %d, beta = %.2f\n', ...
    N, targetMeanDegree, wsBeta);
fprintf('Observed mean degree across replicates = %.4f\n', ...
    mean(meanDegreeReplicates));
fprintf('Final mean proportions:\n');
fprintf('A = %.4f, B = %.4f, C = %.4f, D = %.4f\n', ...
    meanHistory(end, 1), meanHistory(end, 2), ...
    meanHistory(end, 3), meanHistory(end, 4));
fprintf('Final platform revenue = %.4f\n', meanRevenueHistory(end));
fprintf('Results saved to: %s\n', outputDir);


%% ========================================================================
%  局部函数1：运行一次免费模式WS网络异步仿真
%  ========================================================================
function [history, revenueHistory, strategy] = simulateFreeModeAsyncWS( ...
    params, N, T, initialProb, seed, neighborList)

    rng(seed, 'twister');

    % 一维向量保存每个网络节点的策略
    strategy = initializeStrategiesVector(N, initialProb);

    strategyCount = countStrategiesVector(strategy);

    history = zeros(T + 1, 4);
    revenueHistory = zeros(T + 1, 1);

    history(1, :) = strategyCount / N;
    revenueHistory(1) = freePlatformRevenueFromCounts( ...
        strategyCount, params);

    for updateIndex = 1:T

        [strategy, oldStrategy, newStrategy] = ...
            asynchronousFermiUpdateFreeWS(strategy, neighborList, params);

        if oldStrategy ~= newStrategy
            strategyCount(oldStrategy) = strategyCount(oldStrategy) - 1;
            strategyCount(newStrategy) = strategyCount(newStrategy) + 1;
        end

        history(updateIndex + 1, :) = strategyCount / N;

        revenueHistory(updateIndex + 1) = ...
            freePlatformRevenueFromCounts(strategyCount, params);
    end
end


%% ========================================================================
%  局部函数2：免费模式下一次WS网络异步费米更新
%  ========================================================================
function [strategy, oldStrategy, newStrategy] = ...
    asynchronousFermiUpdateFreeWS(strategy, neighborList, params)

    N = numel(strategy);

    % 随机选择焦点参与者
    focalNode = randi(N);

    oldStrategy = strategy(focalNode);
    newStrategy = oldStrategy;

    focalNeighbors = neighborList{focalNode};

    % 理论上K=8的WS网络不会出现孤立节点，这里仍保留保护判断
    if isempty(focalNeighbors)
        return;
    end

    % 从焦点节点的实际邻居中随机选择一个模仿对象
    neighborNode = focalNeighbors(randi(numel(focalNeighbors)));
    neighborStrategy = strategy(neighborNode);

    % 计算焦点参与者和模仿对象的平均效用
    focalPayoff = individualFreePayoffWS( ...
        strategy, focalNode, neighborList, params);
    neighborPayoff = individualFreePayoffWS( ...
        strategy, neighborNode, neighborList, params);

    exponentValue = (focalPayoff - neighborPayoff) / params.kappa;
    exponentValue = max(min(exponentValue, 60), -60);

    imitateProbability = 1 / (1 + exp(exponentValue));

    if rand < imitateProbability
        newStrategy = neighborStrategy;
        strategy(focalNode) = newStrategy;
    end
end


%% ========================================================================
%  局部函数3：计算某个参与者在WS网络上的个体平均效用
%  ========================================================================
function payoff = individualFreePayoffWS( ...
    strategy, focalNode, neighborList, params)

    focalStrategy = strategy(focalNode);

    % D策略效用为0
    if focalStrategy == 4
        payoff = 0;
        return;
    end

    % 在一般无向网络中，参与者i参与：
    % 1. 以自身为中心的局部公共品博弈；
    % 2. 以其每一个邻居为中心的局部公共品博弈。
    % 因此实际参与的局部群组数为 degree(i)+1。
    groupCenters = [focalNode; neighborList{focalNode}(:)];

    totalPayoff = 0;

    for centerIndex = 1:numel(groupCenters)

        centerNode = groupCenters(centerIndex);

        % 以centerNode为中心的局部群组 = 中心节点 + 其全部实际邻居
        groupMembers = [centerNode; neighborList{centerNode}(:)];
        memberStrategies = strategy(groupMembers);

        % 知识供给者：A或B
        nP = sum(memberStrategies == 1 | memberStrategies == 2);

        % 知识享用者：B或C
        nE = sum(memberStrategies == 2 | memberStrategies == 3);

        safeNP = max(nP, 1);

        % C的知识享用效用
        V = params.u * (1 - exp(-params.alpha * nP));

        % B不从自身供给的知识中获取额外效用
        Vminus = params.u * ...
            (1 - exp(-params.alpha * max(nP - 1, 0)));

        % 单位知识供给者非货币收益
        providerReturn = params.hF * nE / safeNP;

        if focalStrategy == 1
            groupPayoff = providerReturn - params.c;

        elseif focalStrategy == 2
            groupPayoff = Vminus + providerReturn - params.c;

        elseif focalStrategy == 3
            groupPayoff = V;

        else
            groupPayoff = 0;
        end

        totalPayoff = totalPayoff + groupPayoff;
    end

    % WS重连后节点度数不同，因此不再固定除以9，
    % 而是除以该参与者实际参加的局部群组数量degree(i)+1。
    payoff = totalPayoff / numel(groupCenters);
end


%% ========================================================================
%  局部函数4：根据策略人数计算免费模式下的平台总收益
%  ========================================================================
function revenue = freePlatformRevenueFromCounts(strategyCount, params)

    nP = strategyCount(1) + strategyCount(2);
    nE = strategyCount(2) + strategyCount(3);

    Vglobal = params.u * (1 - exp(-params.alpha * nP));

    revenue = params.sigma * nE * Vglobal;
end


%% ========================================================================
%  局部函数5：生成Watts-Strogatz小世界网络
%  ========================================================================
function [neighborList, degreeVector] = generateWSNetwork( ...
    N, K, beta, seed)

    rng(seed, 'twister');

    if mod(K, 2) ~= 0
        error('WS网络的K必须为偶数。');
    end
    if K >= N
        error('K必须小于N。');
    end

    halfK = K / 2;

    % 使用稀疏邻接矩阵，N=2500时内存开销很小
    adjacency = sparse(N, N);

    % --------------------------------------------------------------------
    % 第一步：构建规则环形网络
    % 每个节点i与顺时针1,...,K/2个节点相连；由于是无向图，
    % 等价于每个节点最终与左右各K/2个邻居相连，初始度数均为K。
    % --------------------------------------------------------------------
    originalEdgeStart = zeros(N * halfK, 1);
    originalEdgeEnd = zeros(N * halfK, 1);
    edgeCounter = 0;

    for i = 1:N
        for d = 1:halfK
            j = mod(i - 1 + d, N) + 1;

            adjacency(i, j) = 1;
            adjacency(j, i) = 1;

            edgeCounter = edgeCounter + 1;
            originalEdgeStart(edgeCounter) = i;
            originalEdgeEnd(edgeCounter) = j;
        end
    end

    % --------------------------------------------------------------------
    % 第二步：Watts-Strogatz重连
    % 对每条"顺时针原始边"i-j，以概率beta将其改连为i-newJ。
    % 重连时禁止自环和重复边。
    % 每次只删除1条边并增加1条边，因此总边数不变，平均度严格保持K。
    % --------------------------------------------------------------------
    for e = 1:edgeCounter

        if rand >= beta
            continue;
        end

        i = originalEdgeStart(e);
        j = originalEdgeEnd(e);

        % 如果原边由于理论外原因不存在，则跳过
        if adjacency(i, j) == 0
            continue;
        end

        % 暂时删除原边
        adjacency(i, j) = 0;
        adjacency(j, i) = 0;

        % 候选节点：不能是自身，也不能已经与i相连
        currentNeighbors = find(adjacency(i, :));
        forbidden = false(1, N);
        forbidden(i) = true;
        forbidden(currentNeighbors) = true;

        candidates = find(~forbidden);

        if isempty(candidates)
            % 极端情况下无候选节点，则恢复原边
            adjacency(i, j) = 1;
            adjacency(j, i) = 1;
            continue;
        end

        newJ = candidates(randi(numel(candidates)));

        adjacency(i, newJ) = 1;
        adjacency(newJ, i) = 1;
    end

    % 转为邻居列表，提高后续仿真读取效率
    neighborList = cell(N, 1);
    degreeVector = zeros(N, 1);

    for i = 1:N
        neighborList{i} = find(adjacency(i, :));
        degreeVector(i) = numel(neighborList{i});
    end

    % 检查无向性和平均度
    if nnz(adjacency - adjacency') ~= 0
        error('生成的WS邻接矩阵不是对称的。');
    end

    observedMeanDegree = mean(degreeVector);
    if abs(observedMeanDegree - K) > 1e-12
        error('WS网络平均度为%.6f，不等于目标值%d。', ...
            observedMeanDegree, K);
    end
end


%% ========================================================================
%  局部函数6：初始化一维策略向量
%  ========================================================================
function strategy = initializeStrategiesVector(N, probability)

    probability = probability / sum(probability);
    cumulative = cumsum(probability);

    randomValue = rand(N, 1);
    strategy = ones(N, 1, 'uint8');

    strategy(randomValue > cumulative(1)) = 2;
    strategy(randomValue > cumulative(2)) = 3;
    strategy(randomValue > cumulative(3)) = 4;
end


%% ========================================================================
%  局部函数7：统计四类策略人数
%  ========================================================================
function strategyCount = countStrategiesVector(strategy)

    strategyCount = zeros(1, 4);

    strategyCount(1) = nnz(strategy == 1);
    strategyCount(2) = nnz(strategy == 2);
    strategyCount(3) = nnz(strategy == 3);
    strategyCount(4) = nnz(strategy == 4);
end
