-- ===============================================
-- ClickHouse 表概览 - 一键查询脚本
-- ===============================================

-- 第一步：查看所有可用的集群
SELECT '=== 第一步：查看集群列表 ===' AS 步骤;
SELECT 
    cluster AS 集群名称,
    count() AS 节点数量,
    groupArray(host_name) AS 节点列表
FROM system.clusters
GROUP BY cluster;

-- 第二步：查看当前连接的主机信息
SELECT '=== 第二步：当前主机信息 ===' AS 步骤;
SELECT 
    hostName() AS 当前主机名,
    version() AS ClickHouse版本,
    uptime() AS 运行时间秒;

-- 第三步：查看所有表的概览（本地视图）
SELECT '=== 第三步：本地表概览 ===' AS 步骤;
SELECT 
    database AS 数据库名,
    name AS 表名,
    engine AS 引擎类型,
    multiIf(
        engine LIKE '%Distributed%', '分布式表',
        engine LIKE '%Replicated%', '复制表',
        engine LIKE '%MergeTree%', '本地表',
        '其他'
    ) AS 表类型,
    formatReadableQuantity(total_rows) AS 行数_格式化,
    total_rows AS 行数,
    round(total_bytes / 1024 / 1024 / 1024, 2) AS 占用空间_GB
FROM system.tables
WHERE database NOT IN ('system', 'information_schema', 'INFORMATION_SCHEMA')
ORDER BY total_bytes DESC
LIMIT 100;

-- 第四步：通过 parts 表获取更精确的统计（仅 MergeTree 系列）
SELECT '=== 第四步：精确统计（基于分区） ===' AS 步骤;
SELECT 
    database AS 数据库名,
    table AS 表名,
    formatReadableQuantity(sum(rows)) AS 总行数_格式化,
    sum(rows) AS 总行数,
    round(sum(bytes) / 1024 / 1024 / 1024, 2) AS 占用空间_GB,
    count() AS 活跃分区数,
    max(modification_time) AS 最后修改时间
FROM system.parts
WHERE active = 1 
  AND database NOT IN ('system', 'information_schema', 'INFORMATION_SCHEMA')
GROUP BY database, table
ORDER BY sum(bytes) DESC
LIMIT 100;

-- 第五步：数据库级别的汇总
SELECT '=== 第五步：数据库级别汇总 ===' AS 步骤;
SELECT 
    database AS 数据库名,
    count(DISTINCT table) AS 表数量,
    formatReadableQuantity(sum(rows)) AS 总行数_格式化,
    sum(rows) AS 总行数,
    round(sum(bytes) / 1024 / 1024 / 1024, 2) AS 占用空间_GB,
    round(avg(bytes) / 1024 / 1024, 2) AS 平均表大小_MB
FROM system.parts
WHERE active = 1 
  AND database NOT IN ('system', 'information_schema', 'INFORMATION_SCHEMA')
GROUP BY database
ORDER BY sum(bytes) DESC;

-- ===============================================
-- 如果你知道集群名称，取消下面的注释并替换 'YOUR_CLUSTER_NAME'
-- ===============================================
/*
-- 跨集群查询：查看所有节点的表信息
SELECT '=== 跨集群查询：所有节点的表信息 ===' AS 步骤;
SELECT 
    'YOUR_CLUSTER_NAME' AS 集群名称,
    hostName() AS 节点名称,
    database AS 数据库名,
    table AS 表名,
    sum(rows) AS 总行数,
    round(sum(bytes) / 1024 / 1024 / 1024, 2) AS 占用空间_GB
FROM clusterAllReplicas('YOUR_CLUSTER_NAME', system.parts)
WHERE active = 1
  AND database NOT IN ('system', 'information_schema', 'INFORMATION_SCHEMA')
GROUP BY hostName(), database, table
ORDER BY database, table, hostName();
*/

-- ===============================================
-- 汇总统计
-- ===============================================
SELECT '=== 总体统计 ===' AS 步骤;
SELECT 
    count(DISTINCT database) AS 数据库总数,
    count(DISTINCT table) AS 表总数,
    formatReadableQuantity(sum(rows)) AS 总行数,
    round(sum(bytes) / 1024 / 1024 / 1024, 2) AS 总占用空间_GB,
    round(sum(bytes) / 1024 / 1024 / 1024 / 1024, 2) AS 总占用空间_TB
FROM system.parts
WHERE active = 1 
  AND database NOT IN ('system', 'information_schema', 'INFORMATION_SCHEMA');
