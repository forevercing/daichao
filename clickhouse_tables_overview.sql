-- ClickHouse 表概览查询
-- 查询集群中所有表的基本信息：集群名称、表名、行数、占用磁盘空间（GB）

-- 方案1：查询本地表和分布式表的详细信息
SELECT 
    database,
    name AS table_name,
    engine,
    total_rows,
    round(total_bytes / 1024 / 1024 / 1024, 2) AS size_gb
FROM system.tables
WHERE database NOT IN ('system', 'information_schema', 'INFORMATION_SCHEMA')
ORDER BY total_bytes DESC;

-- 方案2：通过 system.parts 获取更准确的统计信息（适用于 MergeTree 系列引擎）
SELECT 
    database,
    table,
    sum(rows) AS total_rows,
    round(sum(bytes) / 1024 / 1024 / 1024, 2) AS size_gb,
    count() AS parts_count,
    max(modification_time) AS last_modified
FROM system.parts
WHERE active = 1 
  AND database NOT IN ('system', 'information_schema', 'INFORMATION_SCHEMA')
GROUP BY database, table
ORDER BY sum(bytes) DESC;

-- 方案3：如果需要查看集群信息，包含集群名称
-- 注意：这需要你知道集群名称，将 'your_cluster_name' 替换为实际的集群名称
/*
SELECT 
    hostName() AS host_name,
    database,
    table,
    sum(rows) AS total_rows,
    round(sum(bytes) / 1024 / 1024 / 1024, 2) AS size_gb
FROM clusterAllReplicas('your_cluster_name', system.parts)
WHERE active = 1
  AND database NOT IN ('system', 'information_schema', 'INFORMATION_SCHEMA')
GROUP BY hostName(), database, table
ORDER BY database, table, hostName();
*/

-- 方案4：查看所有集群配置
SELECT 
    cluster,
    shard_num,
    replica_num,
    host_name,
    host_address,
    port
FROM system.clusters
ORDER BY cluster, shard_num, replica_num;

-- 方案5：综合查询 - 包含表类型判断
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
    formatReadableSize(total_bytes) AS size_formatted,
    round(total_bytes / 1024 / 1024 / 1024, 2) AS size_gb
FROM system.tables
WHERE database NOT IN ('system', 'information_schema', 'INFORMATION_SCHEMA')
ORDER BY total_bytes DESC;

-- 方案6：跨集群汇总 - 每个表只显示一次总计
-- 将 'your_cluster_name' 替换为实际的集群名称
/*
SELECT 
    'your_cluster_name' AS cluster_name,
    database,
    table,
    sum(rows) AS total_rows,
    round(sum(bytes) / 1024 / 1024 / 1024, 2) AS size_gb
FROM cluster('your_cluster_name', system.parts)
WHERE active = 1
  AND database NOT IN ('system', 'information_schema', 'INFORMATION_SCHEMA')
GROUP BY database, table
ORDER BY sum(bytes) DESC;
*/
