# ClickHouse 表概览 - 快速开始

## 问题已解决：语法错误修复

**原因**：ClickHouse 不支持直接使用中文作为列别名，必须使用英文别名。

**解决方案**：所有SQL查询已更新为使用英文列别名。

## 🚀 立即开始（3步搞定）

### 步骤1：连接到ClickHouse

```bash
clickhouse-client --host=your_host --port=9000 --user=your_user --password=your_password
```

### 步骤2：查看集群名称（可选）

```sql
SELECT DISTINCT cluster FROM system.clusters;
```

### 步骤3：执行查询

#### 选项A：查询当前节点的表（最简单）⭐ 推荐

```sql
SELECT 
    database,
    table,
    sum(rows) AS total_rows,
    round(sum(bytes) / 1024 / 1024 / 1024, 2) AS size_gb
FROM system.parts
WHERE active = 1 
  AND database NOT IN ('system', 'information_schema', 'INFORMATION_SCHEMA')
GROUP BY database, table
ORDER BY database, table;
```

#### 选项B：查询整个集群（需要集群名称）

```sql
-- 将 'my_cluster' 替换为你的实际集群名称
SELECT 
    'my_cluster' AS cluster_name,
    database,
    table,
    sum(rows) AS total_rows,
    round(sum(bytes) / 1024 / 1024 / 1024, 2) AS size_gb
FROM cluster('my_cluster', system.parts)
WHERE active = 1 
  AND database NOT IN ('system')
GROUP BY database, table
ORDER BY database, table;
```

#### 选项C：查看每个节点的详细信息

```sql
-- 将 'my_cluster' 替换为你的实际集群名称
SELECT 
    'my_cluster' AS cluster_name,
    hostName() AS host_name,
    database,
    table,
    sum(rows) AS total_rows,
    round(sum(bytes) / 1024 / 1024 / 1024, 2) AS size_gb
FROM clusterAllReplicas('my_cluster', system.parts)
WHERE active = 1 
  AND database NOT IN ('system')
GROUP BY hostName(), database, table
ORDER BY database, table, hostName();
```

## 📋 输出结果说明

### 列名对照表

| 英文列名 | 中文说明 | 示例值 |
|---------|---------|--------|
| cluster_name | 集群名称 | my_cluster |
| host_name | 节点/主机名称 | 001, 002, 003 |
| database | 数据库名 | default |
| table | 表名 | user_events |
| total_rows | 总行数 | 1234567890 |
| size_gb | 占用空间(GB) | 125.67 |

### 示例输出

```
cluster_name   host_name   database   table            total_rows    size_gb
────────────────────────────────────────────────────────────────────────────
my_cluster     001         db1        user_events      1234567890    125.67
my_cluster     002         db1        user_events      1234567890    125.67
my_cluster     003         db1        user_events      1234567890    125.67
my_cluster     001         db1        transactions     987654321     89.23
```

## 💡 常见场景

### 场景1：我只想看总体情况，不关心具体节点

```sql
-- 查看集群名称
SELECT DISTINCT cluster FROM system.clusters;

-- 执行汇总查询（替换 my_cluster）
SELECT 
    'my_cluster' AS cluster_name,
    database,
    table,
    sum(rows) AS total_rows,
    round(sum(bytes) / 1024 / 1024 / 1024, 2) AS size_gb
FROM cluster('my_cluster', system.parts)
WHERE active = 1 
  AND database NOT IN ('system')
GROUP BY database, table
ORDER BY sum(bytes) DESC;
```

### 场景2：我想看TOP 10最大的表

```sql
SELECT 
    database,
    table,
    sum(rows) AS total_rows,
    round(sum(bytes) / 1024 / 1024 / 1024, 2) AS size_gb
FROM system.parts
WHERE active = 1 
  AND database NOT IN ('system')
GROUP BY database, table
ORDER BY sum(bytes) DESC
LIMIT 10;
```

### 场景3：我只关心某个数据库

```sql
SELECT 
    table,
    sum(rows) AS total_rows,
    round(sum(bytes) / 1024 / 1024 / 1024, 2) AS size_gb
FROM system.parts
WHERE active = 1 
  AND database = 'your_database_name'
GROUP BY table
ORDER BY sum(bytes) DESC;
```

### 场景4：我想看可读格式的输出

```sql
SELECT 
    database,
    table,
    formatReadableQuantity(sum(rows)) AS total_rows,
    formatReadableSize(sum(bytes)) AS size
FROM system.parts
WHERE active = 1 
  AND database NOT IN ('system')
GROUP BY database, table
ORDER BY sum(bytes) DESC;
```

## 🔧 使用文件

- **simple_query.sql** - 最简单的查询（复制粘贴即可使用）
- **quick_query.sql** - 完整的一键查询脚本
- **clickhouse_tables_overview.sql** - 多种查询方案
- **README_CLICKHOUSE.md** - 详细使用指南
- **index.php** - PHP示例代码

## ⚠️ 注意事项

1. ✅ 使用英文列别名（已修复）
2. ✅ 确保有查询 system.parts 的权限
3. ✅ 集群查询需要正确的集群名称
4. ✅ 分布式表不占用本地空间
5. ✅ 使用 `active = 1` 只统计活跃分区

## 🆘 遇到问题？

### 错误：Syntax error
- **原因**：使用了中文列别名
- **解决**：使用本文档中的查询语句（已使用英文别名）

### 错误：Unknown cluster
- **原因**：集群名称错误
- **解决**：运行 `SELECT DISTINCT cluster FROM system.clusters;` 查看正确的集群名称

### 错误：Permission denied
- **原因**：没有访问权限
- **解决**：联系管理员授予 system.parts 和 system.clusters 的查询权限

## ✅ 验证查询是否成功

成功的查询应该返回类似这样的结果：

```
database   table          total_rows   size_gb
─────────────────────────────────────────────
db1        events         1000000      10.5
db1        users          50000        0.3
db2        logs           5000000      45.2
```

如果看到这样的输出，说明查询成功！🎉
