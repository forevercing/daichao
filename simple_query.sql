-- ===============================================
-- 最简查询：表的基本信息
-- 输出：集群名称、表名、行数、占用磁盘空间（GB）
-- ===============================================

-- 方法1：如果你不需要查询整个集群，只需要当前连接节点的信息
-- 这是最简单的方法
SELECT 
    database AS 数据库名,
    table AS 表名,
    sum(rows) AS 行数,
    round(sum(bytes) / 1024 / 1024 / 1024, 2) AS 占用空间_GB
FROM system.parts
WHERE active = 1 
  AND database NOT IN ('system', 'information_schema', 'INFORMATION_SCHEMA')
GROUP BY database, table
ORDER BY database, table;


-- 方法2：如果需要包含集群名称，先找到集群名称
-- 步骤1：先执行这个查询找到你的集群名称
-- SELECT DISTINCT cluster FROM system.clusters;

-- 步骤2：将下面的 'my_cluster' 替换为你的实际集群名称，然后执行
/*
SELECT 
    'my_cluster' AS 集群名称,
    database AS 数据库名,
    table AS 表名,
    sum(rows) AS 行数,
    round(sum(bytes) / 1024 / 1024 / 1024, 2) AS 占用空间_GB
FROM cluster('my_cluster', system.parts)
WHERE active = 1 
  AND database NOT IN ('system', 'information_schema', 'INFORMATION_SCHEMA')
GROUP BY database, table
ORDER BY database, table;
*/


-- 方法3：如果需要看每个节点的详细信息
-- 将 'my_cluster' 替换为你的实际集群名称
/*
SELECT 
    'my_cluster' AS 集群名称,
    hostName() AS 节点名称,
    database AS 数据库名,
    table AS 表名,
    sum(rows) AS 行数,
    round(sum(bytes) / 1024 / 1024 / 1024, 2) AS 占用空间_GB
FROM clusterAllReplicas('my_cluster', system.parts)
WHERE active = 1 
  AND database NOT IN ('system', 'information_schema', 'INFORMATION_SCHEMA')
GROUP BY hostName(), database, table
ORDER BY database, table, hostName();
*/
