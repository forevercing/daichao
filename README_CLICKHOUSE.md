# ClickHouse 表概览查询指南

## 问题描述
查询ClickHouse集群中所有表的基本信息，包括：
- 集群名称 (cluster_name)
- 表名 (table)
- 行数 (total_rows)
- 占用磁盘空间GB (size_gb)

## 推荐方案

### 🎯 方案一：快速查看（推荐用于初步了解）

```sql
SELECT 
    database,
    name AS table_name,
    engine,
    formatReadableQuantity(total_rows) AS rows_formatted,
    round(total_bytes / 1024 / 1024 / 1024, 2) AS size_gb
FROM system.tables
WHERE database NOT IN ('system', 'information_schema', 'INFORMATION_SCHEMA')
ORDER BY total_bytes DESC;
```

### 🎯 方案二：精确统计（推荐用于准确数据）⭐ 推荐

```sql
SELECT 
    database,
    table,
    sum(rows) AS total_rows,
    round(sum(bytes) / 1024 / 1024 / 1024, 2) AS size_gb,
    count() AS parts_count
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
    'my_cluster' AS cluster_name,
    hostName() AS host_name,
    database,
    table,
    sum(rows) AS total_rows,
    round(sum(bytes) / 1024 / 1024 / 1024, 2) AS size_gb
FROM clusterAllReplicas('my_cluster', system.parts)
WHERE active = 1
  AND database NOT IN ('system', 'information_schema', 'INFORMATION_SCHEMA')
GROUP BY hostName(), database, table
ORDER BY database, table, hostName();
```

**或者使用（不显示集群名称，但显示每个节点的数据）**
```sql
SELECT 
    hostName() AS host_name,
    database,
    table,
    sum(rows) AS total_rows,
    round(sum(bytes) / 1024 / 1024 / 1024, 2) AS size_gb
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
    'my_cluster' AS cluster_name,
    database,
    table,
    sum(rows) AS total_rows,
    round(sum(bytes) / 1024 / 1024 / 1024, 2) AS size_gb
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

## 列说明

- **database**: 数据库名
- **table**: 表名
- **total_rows**: 总行数
- **size_gb**: 占用空间（GB）
- **cluster_name**: 集群名称
- **host_name**: 主机名/节点名
- **parts_count**: 活跃分区数
- **engine**: 表引擎类型

## 注意事项

- **方案一**（system.tables）：速度快，但对于某些表类型可能不够准确
- **方案二**（system.parts）：更准确，但只适用于 MergeTree 系列引擎的表 ⭐ **推荐使用**
- **方案三/四**：可以查询整个集群的数据，需要知道集群名称
- 排除了 system 数据库，因为这些是系统表
- 分布式表（Distributed）本身不占用空间，它只是指向其他表的视图
- **重要**：ClickHouse 不支持中文作为列别名，所以使用英文别名

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
        WHEN engine LIKE '%Distributed%' THEN 'Distributed'
        WHEN engine LIKE '%Replicated%' THEN 'Replicated'
        ELSE 'Local'
    END AS table_type
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

**Q5：遇到语法错误怎么办？**
- 确保使用英文列别名，不要使用中文
- 确保 ClickHouse 版本支持所使用的函数
- 检查集群名称是否正确

## 输出示例

```
cluster_name   database   table            total_rows    size_gb
my_cluster     db1        user_events      1234567890    125.67
my_cluster     db1        transactions     987654321     89.23
my_cluster     db2        logs             555555555     45.12
```

## 性能优化提示

1. 如果表很多，使用 `LIMIT` 限制结果数量
2. 使用 `formatReadableQuantity()` 和 `formatReadableSize()` 使输出更易读
3. 对于大型集群，跨集群查询可能比较慢，考虑只查询单个节点
4. 定期清理过期的分区可以减少统计时间
