-- ===============================================
-- ClickHouse 表概览 - 一键查询脚本
-- ===============================================

-- 第一步：查看所有可用的集群
SELECT '=== 第一步：查看集群列表 ===' AS step;
SELECT 
    cluster,
    count() AS node_count,
    groupArray(host_name) AS host_list
FROM system.clusters
GROUP BY cluster;

-- 第二步：查看当前连接的主机信息
SELECT '=== 第二步：当前主机信息 ===' AS step;
SELECT 
    hostName() AS current_host,
    version() AS clickhouse_version,
    uptime() AS uptime_seconds;

-- 第三步：查看所有表的概览（本地视图）
SELECT '=== 第三步：本地表概览 ===' AS step;
SELECT 
    database,
    name AS table_name,
    engine,
    multiIf(
        engine LIKE '%Distributed%', 'Distributed',
        engine LIKE '%Replicated%', 'Replicated',
        engine LIKE '%MergeTree%', 'Local',
        'Other'
    ) AS table_type,
    formatReadableQuantity(total_rows) AS rows_formatted,
    total_rows,
    round(total_bytes / 1024 / 1024 / 1024, 2) AS size_gb
FROM system.tables
WHERE database NOT IN ('system', 'information_schema', 'INFORMATION_SCHEMA')
ORDER BY total_bytes DESC
LIMIT 100;

-- 第四步：通过 parts 表获取更精确的统计（仅 MergeTree 系列）
SELECT '=== 第四步：精确统计（基于分区） ===' AS step;
SELECT 
    database,
    table,
    formatReadableQuantity(sum(rows)) AS rows_formatted,
    sum(rows) AS total_rows,
    round(sum(bytes) / 1024 / 1024 / 1024, 2) AS size_gb,
    count() AS active_parts,
    max(modification_time) AS last_modified
FROM system.parts
WHERE active = 1 
  AND database NOT IN ('system', 'information_schema', 'INFORMATION_SCHEMA')
GROUP BY database, table
ORDER BY sum(bytes) DESC
LIMIT 100;

-- 第五步：数据库级别的汇总
SELECT '=== 第五步：数据库级别汇总 ===' AS step;
SELECT 
    database,
    count(DISTINCT table) AS table_count,
    formatReadableQuantity(sum(rows)) AS rows_formatted,
    sum(rows) AS total_rows,
    round(sum(bytes) / 1024 / 1024 / 1024, 2) AS size_gb,
    round(avg(bytes) / 1024 / 1024, 2) AS avg_table_size_mb
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
SELECT '=== 跨集群查询：所有节点的表信息 ===' AS step;
SELECT 
    'YOUR_CLUSTER_NAME' AS cluster_name,
    hostName() AS host_name,
    database,
    table,
    sum(rows) AS total_rows,
    round(sum(bytes) / 1024 / 1024 / 1024, 2) AS size_gb
FROM clusterAllReplicas('YOUR_CLUSTER_NAME', system.parts)
WHERE active = 1
  AND database NOT IN ('system', 'information_schema', 'INFORMATION_SCHEMA')
GROUP BY hostName(), database, table
ORDER BY database, table, hostName();
*/

-- ===============================================
-- 汇总统计
-- ===============================================
SELECT '=== 总体统计 ===' AS step;
SELECT 
    count(DISTINCT database) AS database_count,
    count(DISTINCT table) AS table_count,
    formatReadableQuantity(sum(rows)) AS total_rows,
    round(sum(bytes) / 1024 / 1024 / 1024, 2) AS total_size_gb,
    round(sum(bytes) / 1024 / 1024 / 1024 / 1024, 2) AS total_size_tb
FROM system.parts
WHERE active = 1 
  AND database NOT IN ('system', 'information_schema', 'INFORMATION_SCHEMA');
