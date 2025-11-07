# ClickHouse system.text_log 清理指南

## 📋 什么是 system.text_log？

**system.text_log** 是 ClickHouse 的系统日志表，它记录了 ClickHouse 服务器的所有文本日志信息。

### 包含的日志级别：
- **Trace** - 追踪级别（最详细）
- **Debug** - 调试信息
- **Information** - 一般信息
- **Notice** - 通知
- **Warning** - 警告
- **Error** - 错误
- **Fatal** - 致命错误

### 为什么会占用这么大空间？
1. **日志级别设置过低**（如 Trace/Debug），会记录大量详细信息
2. **没有设置日志保留策略**，导致日志无限累积
3. **高频查询或操作**产生大量日志
4. **长时间运行**从未清理过

## ✅ 可以安全清理吗？

**答案：可以！** 

- ✅ text_log 是**历史日志记录**，清理不会影响 ClickHouse 的正常运行
- ✅ 清理后系统会继续记录新的日志
- ✅ 如果需要保留最近的日志用于排查问题，可以只删除旧数据
- ⚠️ 建议在清理前先导出重要的错误日志（如果需要）

## 🔍 第一步：分析 text_log 表

执行以下查询了解表的情况：

```sql
-- 查看表的基本信息
SELECT 
    table,
    total_rows,
    formatReadableSize(total_bytes) AS size,
    round(total_bytes / 1024 / 1024 / 1024, 2) AS size_gb
FROM system.tables
WHERE database = 'system' AND name = 'text_log';

-- 查看日志的时间范围
SELECT 
    min(event_date) AS earliest_date,
    max(event_date) AS latest_date,
    dateDiff('day', min(event_date), max(event_date)) AS days_span
FROM system.text_log;

-- 查看各日志级别的数量
SELECT 
    level,
    count() AS count,
    formatReadableQuantity(count()) AS count_formatted
FROM system.text_log
GROUP BY level
ORDER BY count DESC;
```

## 🧹 清理方法

### 方法1：完全清空（最快，推荐）⭐

**如果你不需要保留任何历史日志：**

```sql
TRUNCATE TABLE system.text_log;
```

- ✅ 速度最快，立即生效
- ✅ 释放所有空间
- ⚠️ 会删除所有历史日志

### 方法2：保留最近N天的日志

**保留最近7天的日志：**

```sql
ALTER TABLE system.text_log DELETE WHERE event_date < today() - 7;
```

**保留最近30天的日志：**

```sql
ALTER TABLE system.text_log DELETE WHERE event_date < today() - 30;
```

- ✅ 保留最近的日志用于问题排查
- ⚠️ 删除操作是异步的，可能需要等待一段时间才能释放空间

### 方法3：只保留错误日志

**如果你只关心错误信息：**

```sql
ALTER TABLE system.text_log DELETE WHERE level IN ('Trace', 'Debug', 'Information');
```

**或者只保留 Error 和 Warning：**

```sql
ALTER TABLE system.text_log DELETE WHERE level NOT IN ('Error', 'Warning');
```

### 方法4：删除特定时间段的日志

**删除2024年1月之前的所有日志：**

```sql
ALTER TABLE system.text_log DELETE WHERE event_date < '2024-01-01';
```

## 🔄 执行清理的完整步骤

### 步骤1：连接到 ClickHouse

```bash
clickhouse-client --host=your_host --user=your_user --password=your_password
```

### 步骤2：查看当前状态

```sql
SELECT 
    formatReadableSize(total_bytes) AS current_size,
    formatReadableQuantity(total_rows) AS total_records
FROM system.tables
WHERE database = 'system' AND name = 'text_log';
```

### 步骤3：（可选）导出重要日志

如果需要保存错误日志：

```sql
SELECT *
FROM system.text_log
WHERE level IN ('Error', 'Fatal')
  AND event_date >= today() - 30
INTO OUTFILE '/tmp/error_logs.csv'
FORMAT CSV;
```

### 步骤4：执行清理

```sql
-- 选择一种方法执行
TRUNCATE TABLE system.text_log;
```

### 步骤5：验证清理效果

```sql
SELECT 
    formatReadableSize(total_bytes) AS new_size,
    formatReadableQuantity(total_rows) AS remaining_records
FROM system.tables
WHERE database = 'system' AND name = 'text_log';
```

### 步骤6：优化表（可选）

如果使用了 DELETE 而不是 TRUNCATE：

```sql
OPTIMIZE TABLE system.text_log FINAL;
```

## ⚙️ 配置自动清理（预防未来再次占用大量空间）

### 方法1：修改 ClickHouse 配置文件

编辑 `config.xml` 或在 `config.d/` 目录下创建新配置文件：

```xml
<clickhouse>
    <text_log>
        <!-- 设置日志表的 TTL，自动删除旧数据 -->
        <database>system</database>
        <table>text_log</table>
        <flush_interval_milliseconds>7500</flush_interval_milliseconds>
        <partition_by>toYYYYMM(event_date)</partition_by>
        <!-- 设置 TTL：保留30天 -->
        <ttl>event_date + INTERVAL 30 DAY</ttl>
    </text_log>
    
    <!-- 设置日志级别，只记录 Information 及以上级别 -->
    <logger>
        <level>information</level>  <!-- 或 warning，更高级别记录更少 -->
    </logger>
</clickhouse>
```

### 方法2：设置定期清理的计划任务

在服务器上创建 cron 任务：

```bash
# 编辑 crontab
crontab -e

# 添加每周日凌晨2点清理30天前的日志
0 2 * * 0 clickhouse-client --query="ALTER TABLE system.text_log DELETE WHERE event_date < today() - 30"
```

### 方法3：使用 TTL（推荐）⭐

为表添加 TTL 规则（如果表结构允许）：

```sql
-- 注意：system.text_log 是系统表，可能无法直接修改 TTL
-- 但可以通过配置文件设置
```

## 📊 其他需要检查的系统表

除了 text_log，以下系统表也可能占用大量空间：

```sql
SELECT 
    name AS table_name,
    formatReadableSize(total_bytes) AS size,
    round(total_bytes / 1024 / 1024 / 1024, 2) AS size_gb,
    formatReadableQuantity(total_rows) AS rows
FROM system.tables
WHERE database = 'system'
  AND total_bytes > 1024 * 1024 * 1024  -- 大于1GB
ORDER BY total_bytes DESC;
```

### 常见的大型系统表：

| 表名 | 用途 | 是否可清理 |
|------|------|-----------|
| **text_log** | 文本日志 | ✅ 可以 |
| **query_log** | 查询日志 | ✅ 可以 |
| **trace_log** | 跟踪日志 | ✅ 可以 |
| **metric_log** | 指标日志 | ✅ 可以 |
| **asynchronous_metric_log** | 异步指标日志 | ✅ 可以 |
| **part_log** | 分区操作日志 | ✅ 可以 |
| **query_thread_log** | 查询线程日志 | ✅ 可以 |

### 批量清理多个日志表：

```sql
-- 清理所有日志表（保留最近7天）
ALTER TABLE system.text_log DELETE WHERE event_date < today() - 7;
ALTER TABLE system.query_log DELETE WHERE event_date < today() - 7;
ALTER TABLE system.trace_log DELETE WHERE event_date < today() - 7;
ALTER TABLE system.metric_log DELETE WHERE event_date < today() - 7;
ALTER TABLE system.part_log DELETE WHERE event_date < today() - 7;
```

## ⚠️ 注意事项

1. **备份重要日志**：如果需要保留错误日志用于分析，先导出
2. **选择合适的时间**：建议在业务低峰期执行清理
3. **TRUNCATE vs DELETE**：
   - `TRUNCATE` - 立即清空，速度快
   - `DELETE` - 异步删除，可以保留部分数据
4. **权限要求**：需要有足够的权限修改 system 表
5. **空间释放**：DELETE 操作后可能需要等待一段时间才能看到磁盘空间释放

## 🎯 推荐的清理策略

### 对于生产环境：
```sql
-- 保留最近30天的 Error 和 Warning 日志
-- 删除其他所有日志
ALTER TABLE system.text_log DELETE 
WHERE event_date < today() - 30 
   OR level NOT IN ('Error', 'Warning');
```

### 对于开发/测试环境：
```sql
-- 直接清空，保持系统干净
TRUNCATE TABLE system.text_log;
```

## ✅ 验证清理成功

执行清理后，运行以下查询确认：

```sql
SELECT 
    'Before Cleanup' AS status,
    '384 GB' AS size
UNION ALL
SELECT 
    'After Cleanup' AS status,
    formatReadableSize(total_bytes) AS size
FROM system.tables
WHERE database = 'system' AND name = 'text_log';
```

## 📞 需要帮助？

如果遇到以下情况：
- ❌ 清理后空间没有释放
- ❌ 提示权限不足
- ❌ 表被锁定无法操作

可以尝试：
1. 等待几分钟让异步操作完成
2. 执行 `OPTIMIZE TABLE system.text_log FINAL;`
3. 检查是否有其他进程在使用该表
4. 联系 ClickHouse 管理员

---

**总结**：system.text_log 占用384GB是不正常的，可以安全清理。推荐使用 `TRUNCATE TABLE system.text_log;` 快速清理，然后配置日志保留策略防止未来再次发生。
