%% Membership mode simulation on a BA scale-free network
% 会员制收费模式下的知识共享演化博弈仿真程序 —— BA无标度网络版本
%
% 基于原始会员制代码修改：
% 1. 将二维Moore规则网络替换为Barabasi-Albert无标度网络；
% 2. 网络规模N=2500；
% 3. 每个新增节点连接m=4个已有节点；
% 4. 初始完全图取m0=9，使最终总边数恰好为10000，因此平均度严格为8；
% 5. BA网络节点度高度异质，因此个体效用按实际参与的局部群组数取平均；
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

% BA网络参数
baM = 4;                % 每个新增节点连接的已有节点数量
baM0 = 9;               % 初始完全图节点数
% N=2500, m=4, m0=9时：
% 初始边数 = 9*8/2 = 36
% 新增边数 = 4*(2500-9) = 9964
% 总边数 = 10000
% 平均度 = 2*10000/2500 = 8

nReplicates = 10;
masterSeed = 20260710;
initialProb = [0.25, 0.25, 0.25, 0.25];

%% 2. 输出文件夹设置

scriptDir = fileparts(mfilename('fullpath'));
if isempty(scriptDir)
    scriptDir = pwd;
end

outputDir = fullfile(scriptDir, 'results_membership_BA_K8');

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

degreeMatrix = zeros(N, nReplicates);

for rIndex = 1:nReplicates

    runSeed = masterSeed + rIndex - 1;
    networkSeed = masterSeed + 100000 + rIndex - 1;

    adjacency = generateBANetworkExactK8( ...
        N, baM, baM0, networkSeed);

    degreeVector = full(sum(adjacency, 2));
    edgeCount = nnz(triu(adjacency, 1));
    meanDegree = mean(degreeVector);

    meanDegreeByReplicate(rIndex) = meanDegree;
    minDegreeByReplicate(rIndex) = min(degreeVector);
    maxDegreeByReplicate(rIndex) = max(degreeVector);
    edgeCountByReplicate(rIndex) = edgeCount;
    degreeMatrix(:, rIndex) = degreeVector;

    if abs(meanDegree - 8) > 1e-12
        error('BA network mean degree is not 8. Current mean degree = %.12f', ...
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
        'BA mean degree = %.4f, min = %d, max = %d, edges = %d\n'], ...
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
    fullfile(outputDir, 'membership_BA_async_data.csv'));

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
    fullfile(outputDir, 'BA_network_degree_summary.csv'));

degreeTable = array2table( ...
    degreeMatrix, ...
    'VariableNames', ...
    arrayfun(@(x) sprintf('Replicate_%02d', x), ...
        1:nReplicates, ...
        'UniformOutput', false));

degreeTable.Node = (1:N)';
degreeTable = movevars(degreeTable, 'Node', 'Before', 1);

writetable( ...
    degreeTable, ...
    fullfile(outputDir, 'BA_network_node_degrees.csv'));

save( ...
    fullfile(outputDir, 'membership_BA_async_data.mat'), ...
    'params', ...
    'N', ...
    'Q', ...
    'T', ...
    'baM', ...
    'baM0', ...
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
    'degreeMatrix', ...
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
title('Membership mode on BA scale-free network');

legend({ ...
    'A: supply only', ...
    'B: supply and consume', ...
    'C: consume only', ...
    'D: inactive'}, ...
    'Location', 'best');

exportgraphics( ...
    gcf, ...
    fullfile(outputDir, 'membership_BA_strategy_trajectory.png'), ...
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
title('Membership mode on BA network: platform revenue');

exportgraphics( ...
    gcf, ...
    fullfile(outputDir, 'membership_BA_platform_revenue.png'), ...
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
title('Membership mode on BA network: membership status');

legend({'New member purchase', 'Active membership'}, ...
    'Location', 'best');

exportgraphics( ...
    gcf, ...
    fullfile(outputDir, 'membership_BA_membership_status.png'), ...
    'Resolution', 300);

close(gcf);

%% 9. 命令窗口输出最终结果

fprintf('\n');
fprintf('Membership mode on BA network completed.\n');

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

fprintf('Average BA mean degree across replicates = %.4f\n', ...
    mean(meanDegreeByReplicate));

fprintf('Results saved to: %s\n', outputDir);


%% ========================================================================
% 局部函数1：运行一次BA网络上的会员制异步仿真
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

    payoff = totalPayoff / numel(groupCenters);

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
% 局部函数5：生成BA无标度网络，并使平均度严格为8
% ========================================================================

function adjacency = ...
    generateBANetworkExactK8( ...
        N, ...
        m, ...
        m0, ...
        seed)

    if m0 <= m
        error('BA initial network size m0 must be greater than m.');
    end

    if N <= m0
        error('N must be greater than m0.');
    end

    rng(seed, 'twister');

    adjacency = sparse(N, N);
    degreeVector = zeros(N, 1);

    % 初始m0个节点构成完全图
    for i = 1:m0
        for j = (i + 1):m0

            adjacency(i, j) = 1;
            adjacency(j, i) = 1;

        end
    end

    degreeVector(1:m0) = m0 - 1;

    % 每个新增节点按照已有节点度数进行优先连接
    for newNode = (m0 + 1):N

        selectedTargets = zeros(1, m);

        for linkIndex = 1:m

            weights = degreeVector(1:newNode - 1);

            if linkIndex > 1
                weights(selectedTargets(1:linkIndex - 1)) = 0;
            end

            totalWeight = sum(weights);

            if totalWeight <= 0
                error('Invalid BA preferential attachment weights.');
            end

            randomThreshold = rand * totalWeight;
            cumulativeWeight = cumsum(weights);

            target = find( ...
                cumulativeWeight >= randomThreshold, ...
                1, ...
                'first');

            selectedTargets(linkIndex) = target;

        end

        for linkIndex = 1:m

            target = selectedTargets(linkIndex);

            adjacency(newNode, target) = 1;
            adjacency(target, newNode) = 1;

            degreeVector(newNode) = ...
                degreeVector(newNode) + 1;

            degreeVector(target) = ...
                degreeVector(target) + 1;

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
