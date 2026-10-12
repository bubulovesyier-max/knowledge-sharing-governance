%% Free mode simulation on a Barabasi-Albert scale-free network
% 免费模式下的知识共享演化博弈仿真程序：BA无标度网络版本
%
% 相对于原二维Moore规则网络版本，本代码只改变网络结构：
% 1. 网络由二维规则网络改为Barabasi-Albert（BA）无标度网络；
% 2. 节点数保持 N = 2500；
% 3. 目标平均度保持为 8；
% 4. BA增长过程中每个新节点连接 m = 4 个已有节点；
% 5. 为使有限规模网络的平均度"严格"等于8，而不是仅近似等于2m=8，
%    初始网络取 m0 = 2m + 1 = 9 个节点组成完全图。
%    此时初始边数E0 = 9*8/2 = 36，之后每个新节点增加4条边，
%    最终总边数 E = 36 + 4*(2500-9) = 10000，
%    因而平均度 2E/N = 8 恰好成立。
% 6. 新节点按照已有节点当前度数进行优先连接，且同一新节点的4个目标节点不重复；
% 7. BA网络中的节点度数具有明显异质性，因此参与者i参与"以自身及其所有邻居
%    为中心"的局部公共品博弈，并以实际参与的群组数量degree(i)+1取平均效用。
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

% Barabasi-Albert网络参数
targetMeanDegree = 8;    % 目标平均度：严格保持为8
baM = 4;                 % 每个新节点连接的已有节点数；标准BA网络平均度约为2m
baInitialNodes = 9;      % 初始完全图节点数。取2m+1=9可使有限N下平均度严格等于8

nReplicates = 10;        % 独立重复仿真次数
masterSeed = 20260710;   % 主随机种子
initialProb = [0.25, 0.25, 0.25, 0.25];

% 基本检查
if 2 * baM ~= targetMeanDegree
    error('当前设置要求targetMeanDegree = 2*baM。');
end
if baInitialNodes ~= 2 * baM + 1
    error(['若要让BA有限规模网络的平均度严格等于2m，' ...
        '初始完全图节点数应设置为baInitialNodes = 2*baM + 1。']);
end
if baInitialNodes <= baM
    error('baInitialNodes必须大于baM。');
end
if baInitialNodes >= N
    error('baInitialNodes必须小于N。');
end

%% 2. 输出文件夹设置
scriptDir = fileparts(mfilename('fullpath'));
outputDir = fullfile(scriptDir, 'results_free_BA_K8');

if ~exist(outputDir, 'dir')
    mkdir(outputDir);
end

%% 3. 多次独立仿真
allHistory = zeros(T + 1, 4, nReplicates);
allRevenueHistory = zeros(T + 1, nReplicates);
finalStrategies = zeros(N, nReplicates, 'uint8');

% 保存每次BA网络的基本统计量
meanDegreeReplicates = zeros(nReplicates, 1);
minDegreeReplicates = zeros(nReplicates, 1);
maxDegreeReplicates = zeros(nReplicates, 1);
edgeCountReplicates = zeros(nReplicates, 1);
allDegreeVectors = zeros(N, nReplicates, 'uint16');

for rIndex = 1:nReplicates

    % 将网络随机性与策略演化随机性分开，便于复现。
    % 若后续将分成制、会员制也改为BA网络，建议保持同样的networkSeed定义，
    % 这样同一rIndex下三种治理模式使用相同的BA网络实现。
    networkSeed = masterSeed + 200000 + rIndex - 1;
    runSeed = masterSeed + rIndex - 1;

    % 生成一个BA无标度网络
    [neighborList, degreeVector, edgeCount] = generateBANetwork( ...
        N, baM, baInitialNodes, networkSeed);

    meanDegreeReplicates(rIndex) = mean(degreeVector);
    minDegreeReplicates(rIndex) = min(degreeVector);
    maxDegreeReplicates(rIndex) = max(degreeVector);
    edgeCountReplicates(rIndex) = edgeCount;
    allDegreeVectors(:, rIndex) = uint16(degreeVector);

    % 检查平均度是否严格等于目标值8
    if abs(meanDegreeReplicates(rIndex) - targetMeanDegree) > 1e-12
        error('第%d次重复的BA网络平均度不是8，请检查网络生成函数。', rIndex);
    end

    % 运行一次免费模式异步仿真
    [allHistory(:, :, rIndex), allRevenueHistory(:, rIndex), ...
        finalStrategy] = simulateFreeModeAsyncBA( ...
        params, N, T, initialProb, runSeed, neighborList);

    finalStrategies(:, rIndex) = uint8(finalStrategy);

    fprintf(['Replicate %d/%d completed: mean degree = %.4f, ' ...
        'min = %d, max = %d, edges = %d\n'], ...
        rIndex, nReplicates, meanDegreeReplicates(rIndex), ...
        minDegreeReplicates(rIndex), maxDegreeReplicates(rIndex), ...
        edgeCountReplicates(rIndex));
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
    fullfile(outputDir, 'free_mode_BA_K8_async_data.csv'));

networkSummary = table((1:nReplicates)', ...
    meanDegreeReplicates, minDegreeReplicates, ...
    maxDegreeReplicates, edgeCountReplicates, ...
    'VariableNames', {'Replicate', 'MeanDegree', ...
    'MinDegree', 'MaxDegree', 'EdgeCount'});

writetable(networkSummary, ...
    fullfile(outputDir, 'BA_network_degree_summary.csv'));

% 保存每次网络中每个节点的度数，便于后续检查度分布
nodeID = (1:N)';
degreeTable = table(nodeID, 'VariableNames', {'NodeID'});
for rIndex = 1:nReplicates
    degreeTable.(sprintf('Replicate_%02d', rIndex)) = ...
        double(allDegreeVectors(:, rIndex));
end
writetable(degreeTable, ...
    fullfile(outputDir, 'BA_network_node_degrees.csv'));

save(fullfile(outputDir, 'free_mode_BA_K8_async_data.mat'), ...
    'params', 'N', 'T', 'targetMeanDegree', ...
    'baM', 'baInitialNodes', ...
    'nReplicates', 'masterSeed', 'initialProb', ...
    'simulationData', 'networkSummary', ...
    'allHistory', 'allRevenueHistory', ...
    'meanHistory', 'seHistory', ...
    'meanRevenueHistory', 'seRevenueHistory', ...
    'finalStrategies', ...
    'meanDegreeReplicates', 'minDegreeReplicates', ...
    'maxDegreeReplicates', 'edgeCountReplicates', ...
    'allDegreeVectors');

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
title(sprintf('Free mode on BA network: mean degree = %d, m = %d', ...
    targetMeanDegree, baM));

legend({'A: supply only', ...
    'B: supply and consume', ...
    'C: consume only', ...
    'D: inactive'}, ...
    'Location', 'best');

exportgraphics(gcf, fullfile(outputDir, ...
    'free_mode_BA_K8_strategy_trajectory.png'), 'Resolution', 300);

close(gcf);

%% 7. 图2：平台总收益演化图
figure('Visible', 'off', 'Color', 'w', 'Position', [100, 100, 840, 540]);

plot(updateStep, meanRevenueHistory, 'LineWidth', 1.8);
grid on;
box on;
xlim([0, T]);

xlabel('Asynchronous update step');
ylabel('Platform revenue');
title(sprintf('Free mode platform revenue on BA network: mean degree = %d', ...
    targetMeanDegree));

exportgraphics(gcf, fullfile(outputDir, ...
    'free_mode_BA_K8_platform_revenue.png'), 'Resolution', 300);

close(gcf);

%% 8. 命令窗口输出最终结果
fprintf('\nFree mode BA-network asynchronous simulation completed.\n');
fprintf(['BA parameters: N = %d, m = %d, initial clique = %d, ' ...
    'target mean degree = %d\n'], ...
    N, baM, baInitialNodes, targetMeanDegree);
fprintf('Observed mean degree across replicates = %.4f\n', ...
    mean(meanDegreeReplicates));
fprintf('Mean maximum degree across replicates = %.2f\n', ...
    mean(maxDegreeReplicates));
fprintf('Final mean proportions:\n');
fprintf('A = %.4f, B = %.4f, C = %.4f, D = %.4f\n', ...
    meanHistory(end, 1), meanHistory(end, 2), ...
    meanHistory(end, 3), meanHistory(end, 4));
fprintf('Final platform revenue = %.4f\n', meanRevenueHistory(end));
fprintf('Results saved to: %s\n', outputDir);


%% ========================================================================
%  局部函数1：运行一次免费模式BA网络异步仿真
%  ========================================================================
function [history, revenueHistory, strategy] = simulateFreeModeAsyncBA( ...
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
            asynchronousFermiUpdateFreeBA(strategy, neighborList, params);

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
%  局部函数2：免费模式下一次BA网络异步费米更新
%  ========================================================================
function [strategy, oldStrategy, newStrategy] = ...
    asynchronousFermiUpdateFreeBA(strategy, neighborList, params)

    N = numel(strategy);

    % 随机选择焦点参与者
    focalNode = randi(N);

    oldStrategy = strategy(focalNode);
    newStrategy = oldStrategy;

    focalNeighbors = neighborList{focalNode};

    % BA网络从连通初始完全图逐步增长，不会出现孤立节点；保留保护判断
    if isempty(focalNeighbors)
        return;
    end

    % 从焦点节点的实际邻居中随机选择一个模仿对象
    neighborNode = focalNeighbors(randi(numel(focalNeighbors)));
    neighborStrategy = strategy(neighborNode);

    % 计算焦点参与者和模仿对象的平均效用
    focalPayoff = individualFreePayoffBA( ...
        strategy, focalNode, neighborList, params);
    neighborPayoff = individualFreePayoffBA( ...
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
%  局部函数3：计算某个参与者在BA网络上的个体平均效用
%  ========================================================================
function payoff = individualFreePayoffBA( ...
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
        % BA网络中枢纽节点度数较大，因此不同中心对应的群组规模不同。
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

    % BA网络节点度数差异较大，因此不固定除以9，
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
%  局部函数5：生成Barabasi-Albert无标度网络
%  ========================================================================
function [neighborList, degreeVector, edgeCount] = generateBANetwork( ...
    N, m, m0, seed)

    rng(seed, 'twister');

    if m < 1 || floor(m) ~= m
        error('BA参数m必须为正整数。');
    end
    if m0 <= m
        error('初始网络节点数m0必须大于m。');
    end
    if m0 >= N
        error('m0必须小于N。');
    end

    % 使用稀疏邻接矩阵
    adjacency = sparse(N, N);
    degreeVector = zeros(N, 1);

    % --------------------------------------------------------------------
    % 第一步：构建m0个节点组成的完全图
    % 对当前参数m=4、m0=9，初始边数为36，每个初始节点度数为8。
    % --------------------------------------------------------------------
    for i = 1:m0-1
        for j = i+1:m0
            adjacency(i, j) = 1;
            adjacency(j, i) = 1;
            degreeVector(i) = degreeVector(i) + 1;
            degreeVector(j) = degreeVector(j) + 1;
        end
    end

    % --------------------------------------------------------------------
    % 第二步：优先连接增长
    % 从节点m0+1开始，每个新节点连接m个不同的已有节点。
    % 选择概率与已有节点当前度数成正比：P(i) = k_i / sum_j k_j。
    % --------------------------------------------------------------------
    for newNode = m0+1:N

        existingCount = newNode - 1;
        weights = degreeVector(1:existingCount);
        selectedTargets = zeros(m, 1);

        % 按度数进行无放回抽样，保证同一个新节点不会重复连接同一已有节点
        for edgeIndex = 1:m

            totalWeight = sum(weights);
            if totalWeight <= 0
                error('优先连接权重之和为0，BA网络无法继续生成。');
            end

            randomThreshold = rand * totalWeight;
            cumulativeWeight = cumsum(weights);
            targetNode = find(cumulativeWeight >= randomThreshold, 1, 'first');

            selectedTargets(edgeIndex) = targetNode;

            % 无放回：该目标本轮不能再次被选中
            weights(targetNode) = 0;
        end

        % 添加新节点与所选目标节点之间的无向边
        for edgeIndex = 1:m
            targetNode = selectedTargets(edgeIndex);

            adjacency(newNode, targetNode) = 1;
            adjacency(targetNode, newNode) = 1;

            degreeVector(newNode) = degreeVector(newNode) + 1;
            degreeVector(targetNode) = degreeVector(targetNode) + 1;
        end
    end

    % --------------------------------------------------------------------
    % 第三步：转换为邻居列表并进行网络检查
    % --------------------------------------------------------------------
    neighborList = cell(N, 1);

    for i = 1:N
        neighborList{i} = find(adjacency(i, :));
    end

    % 从邻接矩阵重新计算度数，用于一致性检查
    degreeFromAdjacency = full(sum(adjacency, 2));

    if any(degreeVector ~= degreeFromAdjacency)
        error('degreeVector与邻接矩阵计算得到的度数不一致。');
    end

    if nnz(adjacency - adjacency') ~= 0
        error('生成的BA邻接矩阵不是对称的。');
    end

    if nnz(diag(adjacency)) ~= 0
        error('生成的BA网络存在自环。');
    end

    % 无向网络边数
    edgeCount = nnz(triu(adjacency, 1));

    % 理论边数：初始完全图边数 + 每个新增节点的m条边
    expectedEdges = m0 * (m0 - 1) / 2 + m * (N - m0);

    if edgeCount ~= expectedEdges
        error('BA网络边数为%d，但理论值应为%d。', edgeCount, expectedEdges);
    end

    observedMeanDegree = mean(degreeVector);
    expectedMeanDegree = 2 * expectedEdges / N;

    if abs(observedMeanDegree - expectedMeanDegree) > 1e-12
        error('BA网络平均度计算不一致。');
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
