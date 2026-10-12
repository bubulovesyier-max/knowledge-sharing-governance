%% Membership mode simulation for the knowledge-sharing evolutionary game
% 会员制收费模式下的知识共享演化博弈仿真程序
%
% 策略编码：
% A = 1: supply only        只供给知识，不享用知识
% B = 2: supply and consume 既供给知识，也享用知识
% C = 3: consume only       只享用知识，不供给知识
% D = 4: inactive           不供给也不享用，处于低活跃状态
%
% 本代码采用随机异步更新方式：
% 每一个时间步只随机抽取一个参与者进行一次费米规则更新。
% 每次更新后都记录四类策略比例、会员状态和平台总收益。
%
% 本代码按照论文中的会员制逻辑设置：
% 1. 若参与者选择B或C，且tau=0，则当期新购买会员并一次性支付会员费s。
% 2. 当期是否具有会员资格由 M_i^t = max{J(tau_i^t>0), Psi_i^t} 表示。
% 3. 会员收入从平台收益和供给者补偿角度在有效期Q内均匀摊销，即按s/Q计入。
% 4. 会员状态更新按照论文中的写法：若Psi_i^t=1，则tau_i^{t+1}=Q；否则tau_i^{t+1}=max(tau_i^t-1,0)。
% 5. 平台收益计算为平台总收益，不再除以N。

clear;      % 清除工作区中的已有变量
clc;        % 清空命令窗口
close all;  % 关闭所有已经打开的图形窗口

%% 1. 基准参数设置
% 这些参数对应论文模型中的基本变量。

params.c = 1.00;        % c：知识供给成本。策略A和策略B需要承担该成本
params.u = 2.00;        % u：知识享用的最大潜在效用，即V(nP)的上限
params.alpha = 0.25;   % alpha：知识吸收效率，决定知识供给数量转化为知识效用的速度
params.hM = 0.5;      % hM：会员制下知识供给者的非货币收益强度
params.s = 4;       % s：会员费
params.r = 0.45;       % r：会员收入中用于补偿知识供给者的比例
params.Q = 2500;       % Q：会员有效期，表示会员资格持续的异步更新时间步数
params.kappa = 0.20;    % kappa：费米更新规则中的噪声强度
params.sigma = 0.15;    % sigma：平台间接收益能力系数

L = 50;                 % 二维规则网络边长，网络规模为L×L
N = L * L;              % 参与者总数。这里N=50×50=2500
Q = params.Q;           % 会员有效期Q
T = 80000;              % 异步更新时间步数。这里一个时间步表示一次个体策略更新

nReplicates = 10;       % 独立重复仿真次数，用于计算均值和标准误
masterSeed = 20260710;  % 主随机种子，用于保证结果可复现
initialProb = [0.25, 0.25, 0.25, 0.25];  % 初始时刻四类策略的随机分布概率

%% 2. 输出文件夹设置
% 所有结果文件会保存到当前脚本所在目录下的 results_membership_async_total_revenue 文件夹。

scriptDir = fileparts(mfilename('fullpath'));  % 获取当前脚本所在路径
outputDir = fullfile(scriptDir, 'results_membership_async_total_revenue');  % 设置输出文件夹

if ~exist(outputDir, 'dir')  % 如果输出文件夹不存在
    mkdir(outputDir);        % 则创建该文件夹
end

%% 3. 多次独立仿真
% allHistory用于保存每次仿真的策略比例演化结果。
% allRevenueHistory用于保存每次仿真的平台总收益演化结果。
% allNewMemberRate用于保存每次仿真的新购买会员比例。
% allActiveMemberRate用于保存每次仿真的有效会员比例。
% finalStrategies和finalTau用于保存最终空间状态。

allHistory = zeros(T + 1, 4, nReplicates);  % 维度为：(时间步+初始状态) × 4类策略 × 重复次数
allRevenueHistory = zeros(T + 1, nReplicates);  % 维度为：(时间步+初始状态) × 重复次数
allNewMemberRate = zeros(T + 1, nReplicates);  % 保存新购买会员比例
allActiveMemberRate = zeros(T + 1, nReplicates);  % 保存有效会员比例
finalStrategies = zeros(L, L, nReplicates, 'uint8');  % 保存每次仿真的最终策略矩阵
finalTau = zeros(L, L, nReplicates);  % 保存每次仿真的最终会员剩余有效期矩阵

for rIndex = 1:nReplicates

    % 每一次重复仿真使用不同随机种子，但由同一个主随机种子生成，方便复现
    runSeed = masterSeed + rIndex - 1;

    % 运行一次会员制异步仿真
    [allHistory(:, :, rIndex), allRevenueHistory(:, rIndex), ...
        allNewMemberRate(:, rIndex), allActiveMemberRate(:, rIndex), ...
        finalStrategy, finalTau(:, :, rIndex)] = simulateMembershipModeAsync( ...
        params, L, T, Q, initialProb, runSeed);

    % 保存该次仿真的最终策略空间分布
    finalStrategies(:, :, rIndex) = uint8(finalStrategy);
end

%% 4. 计算均值、标准误和派生指标

meanHistory = mean(allHistory, 3);  % 对重复仿真取均值，得到平均策略比例演化
seHistory = std(allHistory, 0, 3) / sqrt(nReplicates);  % 计算策略比例的标准误

meanRevenueHistory = mean(allRevenueHistory, 2);  % 平台总收益的平均演化
seRevenueHistory = std(allRevenueHistory, 0, 2) / sqrt(nReplicates);  % 平台总收益的标准误

meanNewMemberRate = mean(allNewMemberRate, 2);  % 新购买会员比例的平均演化
seNewMemberRate = std(allNewMemberRate, 0, 2) / sqrt(nReplicates);  % 新购买会员比例的标准误

meanActiveMemberRate = mean(allActiveMemberRate, 2);  % 有效会员比例的平均演化
seActiveMemberRate = std(allActiveMemberRate, 0, 2) / sqrt(nReplicates);  % 有效会员比例的标准误

updateStep = (0:T)';  % 异步更新时间步。0表示初始状态

% 知识供给率 = 策略A比例 + 策略B比例
supplyRate = meanHistory(:, 1) + meanHistory(:, 2);

% 知识享用率 = 策略B比例 + 策略C比例
consumeRate = meanHistory(:, 2) + meanHistory(:, 3);

%% 5. 保存数据表
% 表格中保存异步更新时间步、四类策略比例、供给率、享用率、平台总收益和会员状态。

simulationData = table(updateStep, ...
    meanHistory(:, 1), meanHistory(:, 2), ...
    meanHistory(:, 3), meanHistory(:, 4), ...
    seHistory(:, 1), seHistory(:, 2), ...
    seHistory(:, 3), seHistory(:, 4), ...
    supplyRate, consumeRate, ...
    meanRevenueHistory, seRevenueHistory, ...
    meanNewMemberRate, seNewMemberRate, ...
    meanActiveMemberRate, seActiveMemberRate, ...
    'VariableNames', {'UpdateStep', ...
    'A', 'B', 'C', 'D', ...
    'SE_A', 'SE_B', 'SE_C', 'SE_D', ...
    'SupplyRate', 'ConsumeRate', ...
    'PlatformRevenue', ...
    'SE_PlatformRevenue', ...
    'NewMemberRate', 'SE_NewMemberRate', ...
    'ActiveMemberRate', 'SE_ActiveMemberRate'});

% 保存为CSV文件，便于Excel、Origin或Python继续处理
writetable(simulationData, ...
    fullfile(outputDir, 'membership_mode_async_data.csv'));

% 保存为MAT文件，便于MATLAB后续直接调用
save(fullfile(outputDir, 'membership_mode_async_data.mat'), ...
    'params', 'L', 'N', 'Q', 'T', 'nReplicates', ...
    'masterSeed', 'initialProb', ...
    'simulationData', 'allHistory', 'allRevenueHistory', ...
    'allNewMemberRate', 'allActiveMemberRate', ...
    'meanHistory', 'seHistory', ...
    'meanRevenueHistory', 'seRevenueHistory', ...
    'meanNewMemberRate', 'seNewMemberRate', ...
    'meanActiveMemberRate', 'seActiveMemberRate', ...
    'finalStrategies', 'finalTau');

%% 6. 图1：四类策略比例演化图

figure('Visible', 'off', 'Color', 'w', 'Position', [100, 100, 840, 540]);

plot(updateStep, meanHistory(:, 1), 'LineWidth', 1.8);  % 策略A比例
hold on;
plot(updateStep, meanHistory(:, 2), 'LineWidth', 1.8);  % 策略B比例
plot(updateStep, meanHistory(:, 3), 'LineWidth', 1.8);  % 策略C比例
plot(updateStep, meanHistory(:, 4), 'LineWidth', 1.8);  % 策略D比例
hold off;

grid on;
box on;
xlim([0, T]);
ylim([0, 1]);

xlabel('Asynchronous update step');
ylabel('Strategy proportion');
title('Membership mode: asynchronous strategy evolution');

legend({'A: supply only', ...
    'B: supply and consume', ...
    'C: consume only', ...
    'D: inactive'}, ...
    'Location', 'best');

exportgraphics(gcf, fullfile(outputDir, ...
    'membership_mode_async_strategy_trajectory.png'), 'Resolution', 300);

close(gcf);

%% 7. 图2：平台总收益演化图
% 会员制下平台收益由会员费留存收益和平台间接收益共同构成。

figure('Visible', 'off', 'Color', 'w', 'Position', [100, 100, 840, 540]);

plot(updateStep, meanRevenueHistory, 'LineWidth', 1.8);
grid on;
box on;
xlim([0, T]);

xlabel('Asynchronous update step');
ylabel('Platform revenue');
title('Membership mode: platform revenue evolution');

exportgraphics(gcf, fullfile(outputDir, ...
    'membership_mode_async_platform_revenue.png'), 'Resolution', 300);

close(gcf);

%% 8. 图3：会员状态演化图

figure('Visible', 'off', 'Color', 'w', 'Position', [100, 100, 840, 540]);

plot(updateStep, meanNewMemberRate, 'LineWidth', 1.8);  % 新购买会员比例
hold on;
plot(updateStep, meanActiveMemberRate, 'LineWidth', 1.8);  % 有效会员比例
hold off;

grid on;
box on;
xlim([0, T]);
ylim([0, 1]);

xlabel('Asynchronous update step');
ylabel('Membership proportion');
title('Membership mode: membership status evolution');

legend({'New member purchase', 'Active membership'}, ...
    'Location', 'best');

exportgraphics(gcf, fullfile(outputDir, ...
    'membership_mode_async_membership_status.png'), 'Resolution', 300);

close(gcf);

%% 9. 命令窗口输出最终结果

fprintf('Membership mode asynchronous simulation completed.\n');
fprintf('Final mean proportions:\n');
fprintf('A = %.4f, B = %.4f, C = %.4f, D = %.4f\n', ...
    meanHistory(end, 1), meanHistory(end, 2), ...
    meanHistory(end, 3), meanHistory(end, 4));

fprintf('Final active member rate = %.4f\n', meanActiveMemberRate(end));
fprintf('Final platform revenue = %.4f\n', meanRevenueHistory(end));
fprintf('Results saved to: %s\n', outputDir);


%% ========================================================================
%  局部函数1：运行一次会员制异步仿真
%  ========================================================================
function [history, revenueHistory, newMemberRate, activeMemberRate, strategy, tau] = ...
    simulateMembershipModeAsync(params, L, T, Q, initialProb, seed)

    rng(seed, 'twister');  % 设置随机种子，保证该次仿真可复现

    N = L * L;  % 参与者总数

    % 根据初始概率随机生成初始策略矩阵
    strategy = initializeStrategies(L, initialProb);

    % 初始化会员剩余有效期矩阵，初始时所有参与者均无有效会员资格
    tau = zeros(L, L);

    % 统计四类策略的初始人数
    strategyCount = countStrategies(strategy);

    % 初始化记录矩阵
    history = zeros(T + 1, 4);        % 保存四类策略比例
    revenueHistory = zeros(T + 1, 1); % 保存平台总收益
    newMemberRate = zeros(T + 1, 1);  % 保存新购买会员比例
    activeMemberRate = zeros(T + 1, 1); % 保存有效会员比例

    % 记录初始状态
    history(1, :) = strategyCount / N;
    revenueHistory(1) = 0;
    newMemberRate(1) = 0;
    activeMemberRate(1) = 0;

    % 逐个异步时间步进行更新
    for updateIndex = 1:T

        % 当前时刻选择享用知识的参与者，即策略B或策略C
        consumer = (strategy == 2) | (strategy == 3);

        % 会员支付指示函数Psi_i^t：
        % 当参与者选择享用知识且当前没有有效会员资格时，发生新的会员支付行为
        newPurchase = consumer & (tau == 0);

        % 按论文中的M_i^t定义：
        % M_i^t = max{J(tau_i^t>0), Psi_i^t}
        % 也就是此前会员仍有效或当前刚购买会员，均记为当期有效会员
        activeMember = (tau > 0) | newPurchase;

        % 统计当期新购买会员数量和有效会员数量
        nNewPurchase = nnz(newPurchase);
        nActiveMember = nnz(activeMember);

        % 每一步随机选择一个参与者，并根据费米规则决定是否模仿邻居
        [strategy, oldStrategy, newStrategy] = ...
            asynchronousFermiUpdateMembership(strategy, activeMember, newPurchase, params, Q);

        % 如果该参与者策略发生变化，则更新四类策略人数
        if oldStrategy ~= newStrategy
            strategyCount(oldStrategy) = strategyCount(oldStrategy) - 1;
            strategyCount(newStrategy) = strategyCount(newStrategy) + 1;
        end

        % 按照论文中的会员状态更新式更新tau：
        % 若Psi_i^t=1，则tau_i^{t+1}=Q；
        % 若Psi_i^t=0，则tau_i^{t+1}=max(tau_i^t-1,0)。
        tauNext = max(tau - 1, 0);
        tauNext(newPurchase) = Q-1;
        tau = tauNext;

        % 记录当前时刻四类策略比例
        history(updateIndex + 1, :) = strategyCount / N;

        % 记录当前时刻平台总收益
        revenueHistory(updateIndex + 1) = membershipPlatformRevenueFromCounts( ...
            strategyCount, nActiveMember, params, Q);

        % 记录当前时刻新购买会员比例和有效会员比例
        newMemberRate(updateIndex + 1) = nNewPurchase / N;
        activeMemberRate(updateIndex + 1) = nActiveMember / N;
    end
end


%% ========================================================================
%  局部函数2：会员制下的一次异步费米更新
%  ========================================================================
function [strategy, oldStrategy, newStrategy] = ...
    asynchronousFermiUpdateMembership(strategy, activeMember, newPurchase, params, Q)

    L = size(strategy, 1);  % 网络边长

    % 随机选择一个焦点参与者
    row = randi(L);
    col = randi(L);

    oldStrategy = strategy(row, col);  % 焦点参与者更新前的策略
    newStrategy = oldStrategy;         % 默认策略不变

    % Moore邻域中的8个邻居方向，不包括中心点
    offsets = [-1 -1; -1 0; -1 1; ...
                0 -1;          0 1; ...
                1 -1;  1 0;  1 1];

    % 随机选择一个邻居作为模仿对象
    direction = randi(8);

    neighborRow = wrapIndex(row + offsets(direction, 1), L);
    neighborCol = wrapIndex(col + offsets(direction, 2), L);

    neighborStrategy = strategy(neighborRow, neighborCol);

    % 计算焦点参与者和邻居参与者在当前网络状态下的平均效用
    focalPayoff = individualMembershipPayoff( ...
        strategy, activeMember, newPurchase, row, col, params, Q);

    neighborPayoff = individualMembershipPayoff( ...
        strategy, activeMember, newPurchase, neighborRow, neighborCol, params, Q);

    % 费米规则：邻居效用越高，焦点参与者越可能模仿邻居
    exponentValue = (focalPayoff - neighborPayoff) / params.kappa;

    % 限制指数范围，避免数值溢出
    exponentValue = max(min(exponentValue, 60), -60);

    % 计算模仿概率
    imitateProbability = 1 / (1 + exp(exponentValue));

    % 根据模仿概率决定是否更新策略
    if rand < imitateProbability
        newStrategy = neighborStrategy;
        strategy(row, col) = newStrategy;
    end
end


%% ========================================================================
%  局部函数3：计算某个参与者在会员制下的个体平均效用
%  ========================================================================
function payoff = individualMembershipPayoff( ...
    strategy, activeMember, newPurchase, row, col, params, Q)

    L = size(strategy, 1);              % 网络边长
    focalStrategy = strategy(row, col); % 焦点参与者的策略

    % 策略D不供给也不享用知识，效用为0
    if focalStrategy == 4
        payoff = 0;
        return;
    end

    % 包含中心点在内的9个位置。
    % 参与者会参与以自身及8个邻居为中心的9个局部公共品博弈。
    offsets = [-1 -1; -1 0; -1 1; ...
                0 -1;  0 0;  0 1; ...
                1 -1;  1 0;  1 1];

    totalPayoff = 0;  % 累计9个局部群组中的效用

    % 遍历焦点参与者所属的9个局部公共品博弈群组
    for centerIndex = 1:9

        % 当前局部群组的中心位置
        centerRow = wrapIndex(row + offsets(centerIndex, 1), L);
        centerCol = wrapIndex(col + offsets(centerIndex, 2), L);

        nP = 0;  % 当前局部群组中的知识供给者数量
        nE = 0;  % 当前局部群组中的知识享用者数量
        nM = 0;  % 当前局部群组中的有效会员数量

        % 统计当前局部群组中的9个成员
        for memberIndex = 1:9

            memberRow = wrapIndex(centerRow + offsets(memberIndex, 1), L);
            memberCol = wrapIndex(centerCol + offsets(memberIndex, 2), L);

            memberStrategy = strategy(memberRow, memberCol);

            % 策略A和策略B都是知识供给者
            if memberStrategy == 1 || memberStrategy == 2
                nP = nP + 1;
            end

            % 策略B和策略C都是知识享用者
            if memberStrategy == 2 || memberStrategy == 3
                nE = nE + 1;
            end

            % activeMember对应论文中的M_i^t，用于统计有效会员数量n_M
            if activeMember(memberRow, memberCol)
                nM = nM + 1;
            end
        end

        % 防止分母为0。若nP=0，供给者收益项实际上不会被A/B使用。
        safeNP = max(nP, 1);

        % 策略C的知识享用效用：V(nP)
        V = params.u * (1 - exp(-params.alpha * nP));

        % 策略B的知识享用效用：V(nP-1)
        % 含义是B不从自身供给的知识中获得额外知识效用。
        Vminus = params.u * ...
            (1 - exp(-params.alpha * max(nP - 1, 0)));

        % 单位知识供给者获得的收益：
        % r*s*nM/(Q*nP) 表示摊销后的会员收入分配收益；
        % hM*nE/nP 表示非货币收益。
        providerReturn = params.r * params.s * nM / (Q * safeNP) ...
            + params.hM * nE / safeNP;

        % 根据焦点参与者策略计算其在该局部群组中的效用
        if focalStrategy == 1
            % A：只供给知识，获得会员费分配收益和非货币收益，但承担供给成本
            groupPayoff = providerReturn - params.c;

        elseif focalStrategy == 2
            % B：既供给又享用，获得知识效用、会员费分配收益和非货币收益，同时承担供给成本
            groupPayoff = Vminus + providerReturn - params.c;

        elseif focalStrategy == 3
            % C：只享用知识，获得知识效用
            groupPayoff = V;

        else
            % D：低活跃状态，效用为0
            groupPayoff = 0;
        end

        % 累加该局部群组效用
        totalPayoff = totalPayoff + groupPayoff;
    end

    % 取9个局部公共品博弈效用的平均值，作为个体平均效用
    payoff = totalPayoff / 9;

    % 会员制下，会员费s只在当期新购买会员时一次性扣除。
    if newPurchase(row, col)
        payoff = payoff - params.s;
    end
end


%% ========================================================================
%  局部函数4：根据策略人数和有效会员数量计算会员制下的平台总收益
%  ========================================================================
function revenue = membershipPlatformRevenueFromCounts( ...
    strategyCount, nActiveMember, params, Q)

    % 全局知识供给者数量 = A人数 + B人数
    nP = strategyCount(1) + strategyCount(2);

    % 全局知识享用者数量 = B人数 + C人数
    nE = strategyCount(2) + strategyCount(3);

    % 全局知识效用
    Vglobal = params.u * (1 - exp(-params.alpha * nP));

    % 平台获得的会员费留存收益。
    % 按论文逻辑，会员费在有效期Q内均匀摊销，因此当期会员收入按s/Q计入。
    directRevenue = (1 - params.r) * params.s * nActiveMember / Q;

    % 平台间接收益
    indirectRevenue = params.sigma * nE * Vglobal;

    % 会员制下平台总收益 = 会员费留存收益 + 平台间接收益。
    % 注意：这里计算的是平台总收益，不再除以N。
    revenue = directRevenue + indirectRevenue;
end


%% ========================================================================
%  局部函数5：周期边界处理
%  ========================================================================
function index = wrapIndex(index, L)

    % 将越界坐标映射回1到L之间。
    % 例如：0会变成L，L+1会变成1。
    index = mod(index - 1, L) + 1;
end


%% ========================================================================
%  局部函数6：初始化策略矩阵
%  ========================================================================
function strategy = initializeStrategies(L, probability)

    % 保证输入概率之和为1
    probability = probability / sum(probability);

    % 计算累积概率，用于随机分配策略
    cumulative = cumsum(probability);

    % 为每个格点生成0到1之间的随机数
    randomValue = rand(L, L);

    % 默认先设为策略A
    strategy = ones(L, L);

    % 根据随机数落入的概率区间分配策略
    strategy(randomValue > cumulative(1)) = 2;
    strategy(randomValue > cumulative(2)) = 3;
    strategy(randomValue > cumulative(3)) = 4;
end


%% ========================================================================
%  局部函数7：统计四类策略人数
%  ========================================================================
function strategyCount = countStrategies(strategy)

    strategyCount = zeros(1, 4);

    strategyCount(1) = nnz(strategy(:) == 1);  % A人数
    strategyCount(2) = nnz(strategy(:) == 2);  % B人数
    strategyCount(3) = nnz(strategy(:) == 3);  % C人数
    strategyCount(4) = nnz(strategy(:) == 4);  % D人数
end
