-- ClickHouse 表概览查询
-- 查询集群中所有表的基本信息：集群名称、表名、行数、占用磁盘空间（GB）

-- 方案1：查询本地表和分布式表的详细信息
SELECT 
    database AS 数据库名,
    name AS 表名,
    engine AS 引擎类型,
    total_rows AS 行数,
    round(total_bytes / 1024 / 1024 / 1024, 2) AS 占用空间_GB
FROM system.tables
WHERE database NOT IN ('system', 'information_schema', 'INFORMATION_SCHEMA')
ORDER BY total_bytes DESC;

-- 方案2：通过 system.parts 获取更准确的统计信息（适用于 MergeTree 系列引擎）
SELECT 
    database AS 数据库名,
    table AS 表名,
    sum(rows) AS 总行数,
    round(sum(bytes) / 1024 / 1024 / 1024, 2) AS 占用空间_GB,
    count() AS 分区数,
    max(modification_time) AS 最后修改时间
FROM system.parts
WHERE active = 1 
  AND database NOT IN ('system', 'information_schema', 'INFORMATION_SCHEMA')
GROUP BY database, table
ORDER BY sum(bytes) DESC;

-- 方案3：如果需要查看集群信息，包含集群名称
-- 注意：这需要你知道集群名称，将 'your_cluster_name' 替换为实际的集群名称
/*
SELECT 
    hostName() AS 主机名,
    database AS 数据库名,
    table AS 表名,
    sum(rows) AS 总行数,
    round(sum(bytes) / 1024 / 1024 / 1024, 2) AS 占用空间_GB
FROM clusterAllReplicas('your_cluster_name', system.parts)
WHERE active = 1
  AND database NOT IN ('system', 'information_schema', 'INFORMATION_SCHEMA')
GROUP BY hostName(), database, table
ORDER BY database, table, hostName();
*/

-- 方案4：查看所有集群配置
SELECT 
    cluster AS 集群名称,
    shard_num AS 分片编号,
    replica_num AS 副本编号,
    host_name AS 主机名,
    host_address AS 主机地址,
    port AS 端口
FROM system.clusters
ORDER BY cluster, shard_num, replica_num;

-- 方案5：综合查询 - 包含表类型判断
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
    formatReadableSize(total_bytes) AS 占用空间_格式化,
    round(total_bytes / 1024 / 1024 / 1024, 2) AS 占用空间_GB,
    create_table_query AS 建表语句
FROM system.tables
WHERE database NOT IN ('system', 'information_schema', 'INFORMATION_SCHEMA')
ORDER BY total_bytes DESC;
