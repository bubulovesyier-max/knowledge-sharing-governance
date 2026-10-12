%% Membership mode simulation on a WS small-world network
% 会员制收费模式下的知识共享演化博弈仿真程序 —— WS小世界网络版本
%
% 基于原始会员制代码修改：
% 1. 将二维Moore规则网络替换为Watts-Strogatz小世界网络；
% 2. 网络规模N=2500；
% 3. 初始规则环网络每个节点连接左右各4个邻居，初始度K=8；
% 4. 通过重连保持总边数不变，因此平均度严格保持为8；
% 5. WS网络中节点度可发生轻微差异，因此个体效用按实际参与的局部群组数取平均；
% 6. 会员支付、会员有效期、会员收入摊销、平台收益等逻辑保持原代码不变。
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
params.hM = 0.5;
params.s = 4;
params.r = 0.45;
params.Q = 2500;
params.kappa = 0.20;
params.sigma = 0.15;

N = 2500;
Q = params.Q;
T = 80000;

% WS网络参数
wsK = 8;               % 初始规则环网络度数，必须为偶数
wsBeta = 0.20;         % 重连概率，可按需要修改

nReplicates = 10;
masterSeed = 20260710;
initialProb = [0.25, 0.25, 0.25, 0.25];

%% 2. 输出文件夹设置

scriptDir = fileparts(mfilename('fullpath'));
if isempty(scriptDir)
    scriptDir = pwd;
end

outputDir = fullfile(scriptDir, 'results_membership_WS_K8');

if ~exist(outputDir, 'dir')
    mkdir(outputDir);
end

%% 3. 多次独立仿真

allHistory = zeros(T + 1, 4, nReplicates);
allRevenueHistory = zeros(T + 1, nReplicates);
allNewMemberRate = zeros(T + 1, nReplicates);
allActiveMemberRate = zeros(T + 1, nReplicates);

finalStrategies = zeros(N, nReplicates, 'uint8');
finalTau = zeros(N, nReplicates);

meanDegreeByReplicate = zeros(nReplicates, 1);
minDegreeByReplicate = zeros(nReplicates, 1);
maxDegreeByReplicate = zeros(nReplicates, 1);
edgeCountByReplicate = zeros(nReplicates, 1);

for rIndex = 1:nReplicates

    runSeed = masterSeed + rIndex - 1;
    networkSeed = masterSeed + 100000 + rIndex - 1;

    % 生成WS小世界网络
    adjacency = generateWSNetwork(N, wsK, wsBeta, networkSeed);

    degreeVector = full(sum(adjacency, 2));
    edgeCount = nnz(triu(adjacency, 1));
    meanDegree = mean(degreeVector);

    meanDegreeByReplicate(rIndex) = meanDegree;
    minDegreeByReplicate(rIndex) = min(degreeVector);
    maxDegreeByReplicate(rIndex) = max(degreeVector);
    edgeCountByReplicate(rIndex) = edgeCount;

    if abs(meanDegree - 8) > 1e-12
        error('WS network mean degree is not 8. Current mean degree = %.12f', ...
            meanDegree);
    end

    neighbors = adjacencyToNeighborList(adjacency);
    groupMembers = buildGroupMembers(neighbors);

    [allHistory(:, :, rIndex), ...
     allRevenueHistory(:, rIndex), ...
     allNewMemberRate(:, rIndex), ...
     allActiveMemberRate(:, rIndex), ...
     finalStrategy, ...
     finalTau(:, rIndex)] = ...
        simulateMembershipModeAsyncGraph( ...
            params, ...
            N, ...
            T, ...
            Q, ...
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

meanNewMemberRate = mean(allNewMemberRate, 2);
seNewMemberRate = std(allNewMemberRate, 0, 2) / sqrt(nReplicates);

meanActiveMemberRate = mean(allActiveMemberRate, 2);
seActiveMemberRate = std(allActiveMemberRate, 0, 2) / sqrt(nReplicates);

updateStep = (0:T)';

supplyRate = meanHistory(:, 1) + meanHistory(:, 2);
consumeRate = meanHistory(:, 2) + meanHistory(:, 3);

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
    meanNewMemberRate, ...
    seNewMemberRate, ...
    meanActiveMemberRate, ...
    seActiveMemberRate, ...
    'VariableNames', { ...
        'UpdateStep', ...
        'A', 'B', 'C', 'D', ...
        'SE_A', 'SE_B', 'SE_C', 'SE_D', ...
        'SupplyRate', ...
        'ConsumeRate', ...
        'PlatformRevenue', ...
        'SE_PlatformRevenue', ...
        'NewMemberRate', ...
        'SE_NewMemberRate', ...
        'ActiveMemberRate', ...
        'SE_ActiveMemberRate'});

writetable( ...
    simulationData, ...
    fullfile(outputDir, 'membership_WS_async_data.csv'));

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

save( ...
    fullfile(outputDir, 'membership_WS_async_data.mat'), ...
    'params', ...
    'N', ...
    'Q', ...
    'T', ...
    'wsK', ...
    'wsBeta', ...
    'nReplicates', ...
    'masterSeed', ...
    'initialProb', ...
    'simulationData', ...
    'allHistory', ...
    'allRevenueHistory', ...
    'allNewMemberRate', ...
    'allActiveMemberRate', ...
    'meanHistory', ...
    'seHistory', ...
    'meanRevenueHistory', ...
    'seRevenueHistory', ...
    'meanNewMemberRate', ...
    'seNewMemberRate', ...
    'meanActiveMemberRate', ...
    'seActiveMemberRate', ...
    'finalStrategies', ...
    'finalTau', ...
    'networkSummaryTable', ...
    'meanDegreeByReplicate', ...
    'minDegreeByReplicate', ...
    'maxDegreeByReplicate', ...
    'edgeCountByReplicate');

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
title('Membership mode on WS small-world network');

legend({ ...
    'A: supply only', ...
    'B: supply and consume', ...
    'C: consume only', ...
    'D: inactive'}, ...
    'Location', 'best');

exportgraphics( ...
    gcf, ...
    fullfile(outputDir, 'membership_WS_strategy_trajectory.png'), ...
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
title('Membership mode on WS network: platform revenue');

exportgraphics( ...
    gcf, ...
    fullfile(outputDir, 'membership_WS_platform_revenue.png'), ...
    'Resolution', 300);

close(gcf);

%% 8. 图3：会员状态演化图

figure('Visible', 'off', ...
       'Color', 'w', ...
       'Position', [100, 100, 840, 540]);

plot(updateStep, meanNewMemberRate, 'LineWidth', 1.8);
hold on;
plot(updateStep, meanActiveMemberRate, 'LineWidth', 1.8);
hold off;

grid on;
box on;
xlim([0, T]);
ylim([0, 1]);

xlabel('Asynchronous update step');
ylabel('Membership proportion');
title('Membership mode on WS network: membership status');

legend({'New member purchase', 'Active membership'}, ...
    'Location', 'best');

exportgraphics( ...
    gcf, ...
    fullfile(outputDir, 'membership_WS_membership_status.png'), ...
    'Resolution', 300);

close(gcf);

%% 9. 命令窗口输出最终结果

fprintf('\n');
fprintf('Membership mode on WS network completed.\n');

fprintf('Final mean proportions:\n');
fprintf('A = %.4f, B = %.4f, C = %.4f, D = %.4f\n', ...
    meanHistory(end, 1), ...
    meanHistory(end, 2), ...
    meanHistory(end, 3), ...
    meanHistory(end, 4));

fprintf('Final active member rate = %.4f\n', ...
    meanActiveMemberRate(end));

fprintf('Final platform revenue = %.4f\n', ...
    meanRevenueHistory(end));

fprintf('Average WS mean degree across replicates = %.4f\n', ...
    mean(meanDegreeByReplicate));

fprintf('Results saved to: %s\n', outputDir);


%% ========================================================================
% 局部函数1：运行一次WS网络上的会员制异步仿真
% ========================================================================

function [history, revenueHistory, newMemberRate, activeMemberRate, strategy, tau] = ...
    simulateMembershipModeAsyncGraph( ...
        params, ...
        N, ...
        T, ...
        Q, ...
        initialProb, ...
        seed, ...
        neighbors, ...
        groupMembers)

    rng(seed, 'twister');

    strategy = initializeStrategiesVector(N, initialProb);

    % 初始时所有参与者均无有效会员资格
    tau = zeros(N, 1);

    strategyCount = countStrategiesVector(strategy);

    history = zeros(T + 1, 4);
    revenueHistory = zeros(T + 1, 1);
    newMemberRate = zeros(T + 1, 1);
    activeMemberRate = zeros(T + 1, 1);

    history(1, :) = strategyCount / N;
    revenueHistory(1) = 0;
    newMemberRate(1) = 0;
    activeMemberRate(1) = 0;

    for updateIndex = 1:T

        consumer = (strategy == 2) | (strategy == 3);

        newPurchase = consumer & (tau == 0);

        activeMember = (tau > 0) | newPurchase;

        nNewPurchase = nnz(newPurchase);
        nActiveMember = nnz(activeMember);

        [strategy, oldStrategy, newStrategy] = ...
            asynchronousFermiUpdateMembershipGraph( ...
                strategy, ...
                activeMember, ...
                newPurchase, ...
                params, ...
                Q, ...
                neighbors, ...
                groupMembers);

        if oldStrategy ~= newStrategy

            strategyCount(oldStrategy) = ...
                strategyCount(oldStrategy) - 1;

            strategyCount(newStrategy) = ...
                strategyCount(newStrategy) + 1;

        end

        % 与原代码保持一致：
        % 当期新购会员在本时间步结束时设为Q-1，
        % 其余会员剩余期统一减少1
        tauNext = max(tau - 1, 0);
        tauNext(newPurchase) = Q - 1;
        tau = tauNext;

        history(updateIndex + 1, :) = strategyCount / N;

        revenueHistory(updateIndex + 1) = ...
            membershipPlatformRevenueFromCounts( ...
                strategyCount, ...
                nActiveMember, ...
                params, ...
                Q);

        newMemberRate(updateIndex + 1) = nNewPurchase / N;
        activeMemberRate(updateIndex + 1) = nActiveMember / N;

    end

end


%% ========================================================================
% 局部函数2：图网络上的一次会员制异步费米更新
% ========================================================================

function [strategy, oldStrategy, newStrategy] = ...
    asynchronousFermiUpdateMembershipGraph( ...
        strategy, ...
        activeMember, ...
        newPurchase, ...
        params, ...
        Q, ...
        neighbors, ...
        groupMembers)

    N = numel(strategy);

    focal = randi(N);

    oldStrategy = strategy(focal);
    newStrategy = oldStrategy;

    focalNeighbors = neighbors{focal};

    if isempty(focalNeighbors)
        return;
    end

    neighbor = focalNeighbors(randi(numel(focalNeighbors)));
    neighborStrategy = strategy(neighbor);

    focalPayoff = individualMembershipPayoffGraph( ...
        strategy, ...
        activeMember, ...
        newPurchase, ...
        focal, ...
        params, ...
        Q, ...
        neighbors, ...
        groupMembers);

    neighborPayoff = individualMembershipPayoffGraph( ...
        strategy, ...
        activeMember, ...
        newPurchase, ...
        neighbor, ...
        params, ...
        Q, ...
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
% 局部函数3：计算图网络中某参与者的会员制平均效用
% ========================================================================

function payoff = individualMembershipPayoffGraph( ...
    strategy, ...
    activeMember, ...
    newPurchase, ...
    focal, ...
    params, ...
    Q, ...
    neighbors, ...
    groupMembers)

    focalStrategy = strategy(focal);

    if focalStrategy == 4
        payoff = 0;
        return;
    end

    % 焦点参与者参与以自身和其所有直接邻居为中心的局部公共品博弈
    groupCenters = [focal, neighbors{focal}];

    totalPayoff = 0;

    for centerIndex = 1:numel(groupCenters)

        center = groupCenters(centerIndex);
        members = groupMembers{center};

        memberStrategies = strategy(members);

        nP = nnz(memberStrategies == 1 | memberStrategies == 2);
        nE = nnz(memberStrategies == 2 | memberStrategies == 3);
        nM = nnz(activeMember(members));

        safeNP = max(nP, 1);

        V = params.u * ...
            (1 - exp(-params.alpha * nP));

        Vminus = params.u * ...
            (1 - exp( ...
                -params.alpha * max(nP - 1, 0)));

        providerReturn = ...
            params.r * params.s * nM / (Q * safeNP) ...
            + params.hM * nE / safeNP;

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

    % 与规则网络"9个群组取平均"的口径一致，
    % 图网络中按实际参与的局部群组数量取平均
    payoff = totalPayoff / numel(groupCenters);

    % 会员费s仍只在当前参与者当期新购买会员时一次性扣除
    if newPurchase(focal)
        payoff = payoff - params.s;
    end

end


%% ========================================================================
% 局部函数4：平台收益
% ========================================================================

function revenue = ...
    membershipPlatformRevenueFromCounts( ...
        strategyCount, ...
        nActiveMember, ...
        params, ...
        Q)

    nP = strategyCount(1) + strategyCount(2);
    nE = strategyCount(2) + strategyCount(3);

    Vglobal = params.u * ...
        (1 - exp(-params.alpha * nP));

    directRevenue = ...
        (1 - params.r) * ...
        params.s * ...
        nActiveMember / Q;

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
    generateWSNetwork( ...
        N, ...
        K, ...
        beta, ...
        seed)

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

    % 初始规则环网络：每个节点连接左右各K/2个节点
    for i = 1:N
        for distance = 1:halfK

            j = mod(i - 1 + distance, N) + 1;

            adjacency(i, j) = 1;
            adjacency(j, i) = 1;

        end
    end

    % 重连顺时针方向的K/2条边
    % 每次删除1条旧边并增加1条新边，所以总边数不变
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
