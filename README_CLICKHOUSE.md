# ClickHouse 表概览查询指南

## 问题描述
查询ClickHouse集群中所有表的基本信息，包括：
- 集群名称
- 表名
- 行数
- 占用磁盘空间（GB）

## 推荐方案

### 🎯 方案一：快速查看（推荐用于初步了解）

```sql
SELECT 
    database AS 数据库名,
    name AS 表名,
    engine AS 引擎类型,
    formatReadableQuantity(total_rows) AS 行数,
    round(total_bytes / 1024 / 1024 / 1024, 2) AS 占用空间_GB
FROM system.tables
WHERE database NOT IN ('system', 'information_schema', 'INFORMATION_SCHEMA')
ORDER BY total_bytes DESC;
```

### 🎯 方案二：精确统计（推荐用于准确数据）

```sql
SELECT 
    database AS 数据库名,
    table AS 表名,
    sum(rows) AS 总行数,
    round(sum(bytes) / 1024 / 1024 / 1024, 2) AS 占用空间_GB,
    count() AS 分区数
FROM system.parts
WHERE active = 1 
  AND database NOT IN ('system', 'information_schema', 'INFORMATION_SCHEMA')
GROUP BY database, table
ORDER BY sum(bytes) DESC;
```

### 🎯 方案三：跨集群查询（需要知道集群名称）

**步骤1：先查看有哪些集群**
```sql
SELECT DISTINCT cluster FROM system.clusters;
```

**步骤2：使用集群名称查询所有节点的表信息**
```sql
-- 假设集群名称为 'my_cluster'，请替换为实际的集群名称
SELECT 
    cluster() AS 集群名称,
    hostName() AS 节点名称,
    database AS 数据库名,
    table AS 表名,
    sum(rows) AS 总行数,
    round(sum(bytes) / 1024 / 1024 / 1024, 2) AS 占用空间_GB
FROM clusterAllReplicas('my_cluster', system.parts)
WHERE active = 1
  AND database NOT IN ('system', 'information_schema', 'INFORMATION_SCHEMA')
GROUP BY hostName(), database, table
ORDER BY database, table;
```

**或者使用（不显示集群名称，但显示每个节点的数据）**
```sql
SELECT 
    hostName() AS 节点名称,
    database AS 数据库名,
    table AS 表名,
    sum(rows) AS 总行数,
    round(sum(bytes) / 1024 / 1024 / 1024, 2) AS 占用空间_GB
FROM cluster('my_cluster', system.parts)
WHERE active = 1
  AND database NOT IN ('system', 'information_schema', 'INFORMATION_SCHEMA')
GROUP BY hostName(), database, table
ORDER BY database, table, hostName();
```

### 🎯 方案四：完整汇总（每个表只显示一次，适合分布式表）

```sql
-- 先找出集群名称
SELECT DISTINCT cluster FROM system.clusters;

-- 然后执行汇总查询（将 'my_cluster' 替换为实际集群名）
SELECT 
    'my_cluster' AS 集群名称,
    database AS 数据库名,
    table AS 表名,
    sum(rows) AS 总行数,
    round(sum(bytes) / 1024 / 1024 / 1024, 2) AS 占用空间_GB
FROM cluster('my_cluster', system.parts)
WHERE active = 1
  AND database NOT IN ('system', 'information_schema', 'INFORMATION_SCHEMA')
GROUP BY database, table
ORDER BY database, table;
```

## 使用步骤

1. **连接到ClickHouse**
   ```bash
   clickhouse-client --host=your_host --port=9000 --user=your_user --password=your_password
   ```

2. **查看集群配置**
   ```sql
   SELECT cluster, host_name FROM system.clusters;
   ```

3. **执行上述任一查询方案**

## 注意事项

- **方案一**（system.tables）：速度快，但对于某些表类型可能不够准确
- **方案二**（system.parts）：更准确，但只适用于 MergeTree 系列引擎的表
- **方案三/四**：可以查询整个集群的数据，需要知道集群名称
- 排除了 system 数据库，因为这些是系统表
- 分布式表（Distributed）本身不占用空间，它只是指向其他表的视图

## 常见问题

**Q1：如何找到集群名称？**
```sql
SELECT DISTINCT cluster FROM system.clusters;
```

**Q2：如何区分本地表和分布式表？**
```sql
SELECT 
    database,
    name,
    engine,
    CASE 
        WHEN engine LIKE '%Distributed%' THEN '分布式表'
        WHEN engine LIKE '%Replicated%' THEN '复制表'
        ELSE '本地表'
    END AS 表类型
FROM system.tables
WHERE database NOT IN ('system');
```

**Q3：为什么某些表显示0行0字节？**
- 可能是分布式表（Distributed），它们本身不存储数据
- 可能是视图（View）或者物化视图（MaterializedView）
- 表是空的

**Q4：如何只看某个数据库的表？**
```sql
-- 在WHERE条件中指定数据库
WHERE database = 'your_database_name'
```

## 输出示例

```
集群名称        数据库名    表名              总行数          占用空间_GB
my_cluster     db1        user_events       1234567890      125.67
my_cluster     db1        transactions      987654321       89.23
my_cluster     db2        logs              555555555       45.12
```
