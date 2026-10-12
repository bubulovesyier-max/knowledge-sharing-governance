%% Revenue-sharing mode simulation on a WS small-world network
% 分成制收费模式下的知识共享演化博弈仿真程序 —— WS小世界网络版本
%
% 基于原始分成制代码修改：
% 1. 将二维Moore规则网络替换为Watts-Strogatz小世界网络；
% 2. 网络规模N=2500；
% 3. 初始规则环网络每个节点连接左右各4个邻居，初始度K=8；
% 4. 通过重连保持总边数不变，因此平均度严格保持为8；
% 5. WS网络中节点度可发生轻微差异，因此个体效用按实际参与的局部群组数取平均；
% 6. 其余分成制收益结构、费米更新、平台收益和最后10%收益统计保持原逻辑。
%
% 策略编码：
% A = 1: supply only         只供给知识，不享用知识
% B = 2: supply and consume  既供给知识，也享用知识
% C = 3: consume only        只享用知识，不供给知识
% D = 4: inactive            不供给也不享用，处于低活跃状态

clear;
clc;
close all;

%% 1. 基准参数设置

params.c = 1.00;
params.u = 2.00;
params.alpha = 0.25;
params.hD = 0.5;
params.p = 0.6;
params.theta = 0.6;
params.kappa = 0.20;
params.sigma = 0.15;

N = 2500;               % 参与者总数
T = 80000;              % 异步更新时间步数

% WS网络参数
wsK = 8;                % 初始规则环网络度数；必须为偶数
wsBeta = 0.20;          % WS重连概率，可按需要调整，例如0.05/0.10/0.20

nReplicates = 10;
masterSeed = 20260710;
initialProb = [0.25, 0.25, 0.25, 0.25];

%% 2. 输出文件夹设置

scriptDir = fileparts(mfilename('fullpath'));
if isempty(scriptDir)
    scriptDir = pwd;
end

outputDir = fullfile( ...
    scriptDir, ...
    'results_sharing_WS_K8');

if ~exist(outputDir, 'dir')
    mkdir(outputDir);
end

%% 3. 多次独立仿真

allHistory = zeros(T + 1, 4, nReplicates);
allRevenueHistory = zeros(T + 1, nReplicates);
finalStrategies = zeros(N, nReplicates, 'uint8');

meanDegreeByReplicate = zeros(nReplicates, 1);
minDegreeByReplicate = zeros(nReplicates, 1);
maxDegreeByReplicate = zeros(nReplicates, 1);
edgeCountByReplicate = zeros(nReplicates, 1);

for rIndex = 1:nReplicates

    % 将网络生成随机种子与策略演化随机种子分开。
    % 若其他治理模式也采用同样的networkSeed规则，则相同重复编号可使用同一张网络。
    runSeed = masterSeed + rIndex - 1;
    networkSeed = masterSeed + 100000 + rIndex - 1;

    % 生成WS小世界网络
    adjacency = generateWSNetwork( ...
        N, wsK, wsBeta, networkSeed);

    degreeVector = full(sum(adjacency, 2));
    edgeCount = nnz(triu(adjacency, 1));
    meanDegree = mean(degreeVector);

    meanDegreeByReplicate(rIndex) = meanDegree;
    minDegreeByReplicate(rIndex) = min(degreeVector);
    maxDegreeByReplicate(rIndex) = max(degreeVector);
    edgeCountByReplicate(rIndex) = edgeCount;

    % 平均度应严格为8
    if abs(meanDegree - 8) > 1e-12
        error('WS network mean degree is not 8. Current mean degree = %.12f', ...
            meanDegree);
    end

    % 将邻接矩阵转成邻居列表，减少仿真中的重复查找
    neighbors = adjacencyToNeighborList(adjacency);

    % 每个局部公共品博弈群组 = 中心节点 + 该节点的所有直接邻居
    groupMembers = buildGroupMembers(neighbors);

    [allHistory(:, :, rIndex), ...
     allRevenueHistory(:, rIndex), ...
     finalStrategy] = ...
        simulateSharingModeAsyncGraph( ...
            params, ...
            N, ...
            T, ...
            initialProb, ...
            runSeed, ...
            neighbors, ...
            groupMembers);

    finalStrategies(:, rIndex) = uint8(finalStrategy);

    fprintf(['Replicate %d/%d completed. ', ...
        'WS mean degree = %.4f, min = %d, max = %d, edges = %d\n'], ...
        rIndex, nReplicates, meanDegree, ...
        min(degreeVector), max(degreeVector), edgeCount);

end

%% 4. 计算均值、标准误和派生指标

meanHistory = mean(allHistory, 3);
seHistory = std(allHistory, 0, 3) / sqrt(nReplicates);

meanRevenueHistory = mean(allRevenueHistory, 2);
seRevenueHistory = std(allRevenueHistory, 0, 2) / sqrt(nReplicates);

updateStep = (0:T)';

supplyRate = meanHistory(:, 1) + meanHistory(:, 2);
consumeRate = meanHistory(:, 2) + meanHistory(:, 3);

%% 4.1 最后10%时间段的平台收益

steadyFraction = 0.10;
steadyWindowLength = max(1, ceil(T * steadyFraction));
steadyStartUpdate = T - steadyWindowLength + 1;
steadyEndUpdate = T;

steadyStartIndex = steadyStartUpdate + 1;
steadyEndIndex = steadyEndUpdate + 1;

steadyUpdateStep = updateStep(steadyStartIndex:steadyEndIndex);

steadyRevenueAllReplicates = ...
    allRevenueHistory(steadyStartIndex:steadyEndIndex, :);

steadyMeanRevenueHistory = mean(steadyRevenueAllReplicates, 2);

steadySERevenueHistory = ...
    std(steadyRevenueAllReplicates, 0, 2) / sqrt(nReplicates);

steadyRevenueByReplicate = ...
    mean(steadyRevenueAllReplicates, 1)';

steadyPlatformRevenue = mean(steadyRevenueByReplicate);
steadyPlatformRevenueStd = std(steadyRevenueByReplicate, 0);
steadyPlatformRevenueSE = ...
    steadyPlatformRevenueStd / sqrt(nReplicates);

%% 5. 保存数据表

simulationData = table( ...
    updateStep, ...
    meanHistory(:, 1), ...
    meanHistory(:, 2), ...
    meanHistory(:, 3), ...
    meanHistory(:, 4), ...
    seHistory(:, 1), ...
    seHistory(:, 2), ...
    seHistory(:, 3), ...
    seHistory(:, 4), ...
    supplyRate, ...
    consumeRate, ...
    meanRevenueHistory, ...
    seRevenueHistory, ...
    'VariableNames', { ...
        'UpdateStep', ...
        'A', 'B', 'C', 'D', ...
        'SE_A', 'SE_B', 'SE_C', 'SE_D', ...
        'SupplyRate', ...
        'ConsumeRate', ...
        'PlatformRevenue', ...
        'SE_PlatformRevenue'});

writetable( ...
    simulationData, ...
    fullfile(outputDir, 'sharing_WS_async_data.csv'));

%% 5.1 保存网络度数统计

networkSummaryTable = table( ...
    (1:nReplicates)', ...
    meanDegreeByReplicate, ...
    minDegreeByReplicate, ...
    maxDegreeByReplicate, ...
    edgeCountByReplicate, ...
    'VariableNames', { ...
        'Replicate', ...
        'MeanDegree', ...
        'MinDegree', ...
        'MaxDegree', ...
        'EdgeCount'});

writetable( ...
    networkSummaryTable, ...
    fullfile(outputDir, 'WS_network_degree_summary.csv'));

%% 5.2 保存最后10%平台收益

steadyRevenueExcelFile = fullfile( ...
    outputDir, ...
    'sharing_WS_last10_percent_revenue.xlsx');

if isfile(steadyRevenueExcelFile)
    delete(steadyRevenueExcelFile);
end

steadyRevenueTrajectoryTable = table( ...
    steadyUpdateStep, ...
    steadyMeanRevenueHistory, ...
    steadySERevenueHistory, ...
    'VariableNames', { ...
        'UpdateStep', ...
        'MeanPlatformRevenue', ...
        'SE_PlatformRevenue'});

for rIndex = 1:nReplicates
    replicateVariableName = sprintf('Replicate_%02d', rIndex);
    steadyRevenueTrajectoryTable.(replicateVariableName) = ...
        steadyRevenueAllReplicates(:, rIndex);
end

replicateIndex = (1:nReplicates)';

steadyRevenueReplicateTable = table( ...
    replicateIndex, ...
    steadyRevenueByReplicate, ...
    'VariableNames', { ...
        'Replicate', ...
        'MeanRevenueInLast10Percent'});

steadyRevenueSummaryTable = table( ...
    params.p, ...
    params.theta, ...
    wsK, ...
    wsBeta, ...
    mean(meanDegreeByReplicate), ...
    steadyFraction, ...
    steadyStartUpdate, ...
    steadyEndUpdate, ...
    steadyWindowLength, ...
    nReplicates, ...
    steadyPlatformRevenue, ...
    steadyPlatformRevenueStd, ...
    steadyPlatformRevenueSE, ...
    'VariableNames', { ...
        'KnowledgePrice_p', ...
        'RevenueSharingRatio_theta', ...
        'WS_InitialDegree_K', ...
        'WS_RewiringProbability_beta', ...
        'MeanNetworkDegree', ...
        'SteadyFraction', ...
        'StartUpdateStep', ...
        'EndUpdateStep', ...
        'WindowLength', ...
        'NumberOfReplicates', ...
        'MeanSteadyPlatformRevenue', ...
        'SD_SteadyPlatformRevenue', ...
        'SE_SteadyPlatformRevenue'});

writetable(steadyRevenueTrajectoryTable, ...
    steadyRevenueExcelFile, 'Sheet', 'Last10PercentTrajectory');

writetable(steadyRevenueReplicateTable, ...
    steadyRevenueExcelFile, 'Sheet', 'ReplicateMean');

writetable(steadyRevenueSummaryTable, ...
    steadyRevenueExcelFile, 'Sheet', 'Summary');

%% 5.3 保存MAT文件

save( ...
    fullfile(outputDir, 'sharing_WS_async_data.mat'), ...
    'params', ...
    'N', ...
    'T', ...
    'wsK', ...
    'wsBeta', ...
    'nReplicates', ...
    'masterSeed', ...
    'initialProb', ...
    'simulationData', ...
    'allHistory', ...
    'allRevenueHistory', ...
    'meanHistory', ...
    'seHistory', ...
    'meanRevenueHistory', ...
    'seRevenueHistory', ...
    'finalStrategies', ...
    'networkSummaryTable', ...
    'meanDegreeByReplicate', ...
    'minDegreeByReplicate', ...
    'maxDegreeByReplicate', ...
    'edgeCountByReplicate', ...
    'steadyFraction', ...
    'steadyWindowLength', ...
    'steadyStartUpdate', ...
    'steadyEndUpdate', ...
    'steadyRevenueAllReplicates', ...
    'steadyRevenueByReplicate', ...
    'steadyPlatformRevenue', ...
    'steadyPlatformRevenueStd', ...
    'steadyPlatformRevenueSE');

%% 6. 图1：四类策略比例演化图

figure('Visible', 'off', ...
       'Color', 'w', ...
       'Position', [100, 100, 840, 540]);

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
title('Revenue-sharing mode on WS network');

legend({ ...
    'A: supply only', ...
    'B: supply and consume', ...
    'C: consume only', ...
    'D: inactive'}, ...
    'Location', 'best');

exportgraphics( ...
    gcf, ...
    fullfile(outputDir, 'sharing_WS_strategy_trajectory.png'), ...
    'Resolution', 300);

close(gcf);

%% 7. 图2：平台总收益演化图

figure('Visible', 'off', ...
       'Color', 'w', ...
       'Position', [100, 100, 840, 540]);

plot(updateStep, meanRevenueHistory, 'LineWidth', 1.8);
grid on;
box on;
xlim([0, T]);

xlabel('Asynchronous update step');
ylabel('Platform revenue');
title('Revenue-sharing mode on WS network: platform revenue');

exportgraphics( ...
    gcf, ...
    fullfile(outputDir, 'sharing_WS_platform_revenue.png'), ...
    'Resolution', 300);

close(gcf);

%% 8. 命令窗口输出最终结果

fprintf('\n');
fprintf('Revenue-sharing mode on WS network completed.\n');

fprintf('Final mean proportions:\n');
fprintf('A = %.4f, B = %.4f, C = %.4f, D = %.4f\n', ...
    meanHistory(end, 1), ...
    meanHistory(end, 2), ...
    meanHistory(end, 3), ...
    meanHistory(end, 4));

fprintf('Final platform revenue = %.4f\n', ...
    meanRevenueHistory(end));

fprintf('Average WS mean degree across replicates = %.4f\n', ...
    mean(meanDegreeByReplicate));

fprintf('Last 10%% mean platform revenue = %.4f\n', ...
    steadyPlatformRevenue);

fprintf('Results saved to: %s\n', outputDir);


%% ========================================================================
% 局部函数1：运行一次WS网络上的分成制异步仿真
% ========================================================================

function [history, revenueHistory, strategy] = ...
    simulateSharingModeAsyncGraph( ...
        params, ...
        N, ...
        T, ...
        initialProb, ...
        seed, ...
        neighbors, ...
        groupMembers)

    rng(seed, 'twister');

    strategy = initializeStrategiesVector(N, initialProb);
    strategyCount = countStrategiesVector(strategy);

    history = zeros(T + 1, 4);
    revenueHistory = zeros(T + 1, 1);

    history(1, :) = strategyCount / N;

    revenueHistory(1) = ...
        sharingPlatformRevenueFromCounts( ...
            strategyCount, ...
            params);

    for updateIndex = 1:T

        [strategy, oldStrategy, newStrategy] = ...
            asynchronousFermiUpdateSharingGraph( ...
                strategy, ...
                params, ...
                neighbors, ...
                groupMembers);

        if oldStrategy ~= newStrategy

            strategyCount(oldStrategy) = ...
                strategyCount(oldStrategy) - 1;

            strategyCount(newStrategy) = ...
                strategyCount(newStrategy) + 1;

        end

        history(updateIndex + 1, :) = ...
            strategyCount / N;

        revenueHistory(updateIndex + 1) = ...
            sharingPlatformRevenueFromCounts( ...
                strategyCount, ...
                params);

    end

end


%% ========================================================================
% 局部函数2：图网络上的一次异步费米更新
% ========================================================================

function [strategy, oldStrategy, newStrategy] = ...
    asynchronousFermiUpdateSharingGraph( ...
        strategy, ...
        params, ...
        neighbors, ...
        groupMembers)

    N = numel(strategy);

    focal = randi(N);

    oldStrategy = strategy(focal);
    newStrategy = oldStrategy;

    focalNeighbors = neighbors{focal};

    % 理论上WS网络不会出现孤立节点；保留保护判断
    if isempty(focalNeighbors)
        return;
    end

    neighbor = focalNeighbors(randi(numel(focalNeighbors)));
    neighborStrategy = strategy(neighbor);

    focalPayoff = individualSharingPayoffGraph( ...
        strategy, ...
        focal, ...
        params, ...
        neighbors, ...
        groupMembers);

    neighborPayoff = individualSharingPayoffGraph( ...
        strategy, ...
        neighbor, ...
        params, ...
        neighbors, ...
        groupMembers);

    exponentValue = ...
        (focalPayoff - neighborPayoff) / params.kappa;

    exponentValue = max(min(exponentValue, 60), -60);

    imitateProbability = ...
        1 / (1 + exp(exponentValue));

    if rand < imitateProbability
        newStrategy = neighborStrategy;
        strategy(focal) = newStrategy;
    end

end


%% ========================================================================
% 局部函数3：计算图网络中某参与者的分成制平均效用
% ========================================================================

function payoff = individualSharingPayoffGraph( ...
    strategy, ...
    focal, ...
    params, ...
    neighbors, ...
    groupMembers)

    focalStrategy = strategy(focal);

    if focalStrategy == 4
        payoff = 0;
        return;
    end

    % 焦点参与者参加：以自身为中心的群组 + 以其所有直接邻居为中心的群组
    groupCenters = [focal, neighbors{focal}];

    totalPayoff = 0;

    for centerIndex = 1:numel(groupCenters)

        center = groupCenters(centerIndex);
        members = groupMembers{center};
        memberStrategies = strategy(members);

        nP = nnz(memberStrategies == 1 | memberStrategies == 2);
        nE = nnz(memberStrategies == 2 | memberStrategies == 3);

        safeNP = max(nP, 1);

        V = params.u * ...
            (1 - exp(-params.alpha * nP));

        Vminus = params.u * ...
            (1 - exp( ...
                -params.alpha * max(nP - 1, 0)));

        providerReturn = ...
            (params.theta * params.p + params.hD) * ...
            nE / safeNP;

        if focalStrategy == 1

            groupPayoff = ...
                providerReturn - params.c;

        elseif focalStrategy == 2

            groupPayoff = ...
                Vminus + providerReturn - params.c;

        elseif focalStrategy == 3

            groupPayoff = V;

        else

            groupPayoff = 0;

        end

        totalPayoff = totalPayoff + groupPayoff;

    end

    % 与原规则网络"9个局部群组取平均"的口径一致：
    % 图网络中按实际参与的局部群组数量取平均
    payoff = totalPayoff / numel(groupCenters);

    % B和C仍然只按一次知识享用行为扣除价格p，
    % 不随参与的局部公共品博弈数量重复扣费
    if focalStrategy == 2 || focalStrategy == 3
        payoff = payoff - params.p;
    end

end


%% ========================================================================
% 局部函数4：平台收益
% ========================================================================

function revenue = ...
    sharingPlatformRevenueFromCounts( ...
        strategyCount, ...
        params)

    nP = strategyCount(1) + strategyCount(2);
    nE = strategyCount(2) + strategyCount(3);

    Vglobal = params.u * ...
        (1 - exp(-params.alpha * nP));

    directRevenue = ...
        (1 - params.theta) * ...
        params.p * ...
        nE;

    indirectRevenue = ...
        params.sigma * ...
        nE * ...
        Vglobal;

    revenue = directRevenue + indirectRevenue;

end


%% ========================================================================
% 局部函数5：生成WS小世界网络
% ========================================================================

function adjacency = ...
    generateWSNetwork(N, K, beta, seed)

    if mod(K, 2) ~= 0
        error('WS initial degree K must be even.');
    end

    if K >= N
        error('WS initial degree K must be smaller than N.');
    end

    if beta < 0 || beta > 1
        error('WS rewiring probability beta must be between 0 and 1.');
    end

    rng(seed, 'twister');

    halfK = K / 2;

    adjacency = sparse(N, N);

    % 第一步：建立规则环网络，每个节点连接左右各K/2个邻居
    for i = 1:N
        for distance = 1:halfK

            j = mod(i - 1 + distance, N) + 1;

            adjacency(i, j) = 1;
            adjacency(j, i) = 1;

        end
    end

    % 第二步：仅处理每个节点的"顺时针"K/2条原始边
    % 每次重连删除1条边并增加1条边，因此总边数严格保持不变
    for i = 1:N

        for distance = 1:halfK

            oldNeighbor = ...
                mod(i - 1 + distance, N) + 1;

            if rand < beta

                currentNeighbors = find(adjacency(i, :));

                forbidden = false(1, N);
                forbidden(i) = true;
                forbidden(currentNeighbors) = true;

                candidates = find(~forbidden);

                if ~isempty(candidates)

                    newNeighbor = ...
                        candidates(randi(numel(candidates)));

                    adjacency(i, oldNeighbor) = 0;
                    adjacency(oldNeighbor, i) = 0;

                    adjacency(i, newNeighbor) = 1;
                    adjacency(newNeighbor, i) = 1;

                end
            end
        end
    end

    adjacency = spones(adjacency);

end


%% ========================================================================
% 局部函数6：邻接矩阵转邻居列表
% ========================================================================

function neighbors = adjacencyToNeighborList(adjacency)

    N = size(adjacency, 1);
    neighbors = cell(N, 1);

    for i = 1:N
        neighbors{i} = find(adjacency(i, :));
    end

end


%% ========================================================================
% 局部函数7：构建每个中心节点的局部公共品博弈群组
% ========================================================================

function groupMembers = buildGroupMembers(neighbors)

    N = numel(neighbors);
    groupMembers = cell(N, 1);

    for i = 1:N
        groupMembers{i} = [i, neighbors{i}];
    end

end


%% ========================================================================
% 局部函数8：初始化策略向量
% ========================================================================

function strategy = ...
    initializeStrategiesVector( ...
        N, ...
        probability)

    probability = probability / sum(probability);
    cumulative = cumsum(probability);

    randomValue = rand(N, 1);

    strategy = ones(N, 1, 'uint8');

    strategy(randomValue > cumulative(1)) = 2;
    strategy(randomValue > cumulative(2)) = 3;
    strategy(randomValue > cumulative(3)) = 4;

end


%% ========================================================================
% 局部函数9：统计四类策略人数
% ========================================================================

function strategyCount = ...
    countStrategiesVector(strategy)

    strategyCount = zeros(1, 4);

    strategyCount(1) = nnz(strategy == 1);
    strategyCount(2) = nnz(strategy == 2);
    strategyCount(3) = nnz(strategy == 3);
    strategyCount(4) = nnz(strategy == 4);

end
