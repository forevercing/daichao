# 解决 TRUNCATE TABLE 报错指南

## 🔴 错误信息

```
Code: 359. DB::Exception: Table or Partition in system.text_log was not dropped.
Reason: Size (413.21 GB) is greater than max_table_size_to_drop (50.00 GB)
```

## 📋 问题原因

ClickHouse 有一个**安全保护机制**，防止误删大表：
- 默认限制：不能删除/清空超过 50GB 的表
- 你的表：413.21 GB（超过限制 8倍多）
- 由于你没有服务器权限，无法创建强制文件

## ✅ 解决方案（按推荐顺序）

### 🎯 方案1：在查询中临时设置参数（最简单）⭐⭐⭐

**直接在 TRUNCATE 语句中添加 SETTINGS：**

```sql
TRUNCATE TABLE system.text_log SETTINGS max_table_size_to_drop = 0;
```

**说明**：
- ✅ 最简单快速的方法
- ✅ 不需要服务器权限
- ✅ `max_table_size_to_drop = 0` 表示不限制大小
- ⚠️ 需要你的用户有足够的权限

**如果上面的命令报权限错误，可以尝试：**

```sql
-- 设置一个足够大的值（500GB）
TRUNCATE TABLE system.text_log SETTINGS max_table_size_to_drop = 500000000000;
```

---

### 🎯 方案2：使用 DELETE 分批删除（稳妥但慢）⭐⭐

如果方案1不行，使用 DELETE 逐步删除数据。

#### 步骤1：查看数据的日期分布

```sql
SELECT 
    event_date,
    formatReadableQuantity(count()) AS records,
    round(count() * 100.0 / (SELECT count() FROM system.text_log), 2) AS percentage
FROM system.text_log
GROUP BY event_date
ORDER BY event_date;
```

#### 步骤2：分批删除旧数据

**第一批：删除90天前的数据**

```sql
ALTER TABLE system.text_log DELETE WHERE event_date < today() - 90;
```

**等待5-10分钟**，让删除操作完成，然后继续：

**第二批：删除60天前的数据**

```sql
ALTER TABLE system.text_log DELETE WHERE event_date < today() - 60;
```

**第三批：删除30天前的数据**

```sql
ALTER TABLE system.text_log DELETE WHERE event_date < today() - 30;
```

**第四批：删除7天前的数据**

```sql
ALTER TABLE system.text_log DELETE WHERE event_date < today() - 7;
```

**最后（如果需要）：清空所有剩余数据**

```sql
ALTER TABLE system.text_log DELETE WHERE 1=1;
```

#### 步骤3：验证进度

在每次删除后检查：

```sql
SELECT 
    formatReadableSize(total_bytes) AS current_size,
    round(total_bytes / 1024 / 1024 / 1024, 2) AS size_gb,
    formatReadableQuantity(total_rows) AS remaining_records
FROM system.tables
WHERE database = 'system' AND name = 'text_log';
```

---

### 🎯 方案3：按分区删除（如果表有分区）⭐⭐⭐

**按分区删除比 DELETE 快得多！**

#### 步骤1：查看所有分区

```sql
SELECT 
    partition,
    formatReadableQuantity(sum(rows)) AS rows,
    formatReadableSize(sum(bytes)) AS size,
    round(sum(bytes) / 1024 / 1024 / 1024, 2) AS size_gb
FROM system.parts
WHERE database = 'system' 
  AND table = 'text_log' 
  AND active = 1
GROUP BY partition
ORDER BY partition;
```

#### 步骤2：逐个删除分区

```sql
-- 假设分区是按月份的（202401, 202402, ...）
ALTER TABLE system.text_log DROP PARTITION '202401';
ALTER TABLE system.text_log DROP PARTITION '202402';
ALTER TABLE system.text_log DROP PARTITION '202403';
-- 继续删除其他分区...
```

**优点**：
- ✅ 比 DELETE 快很多
- ✅ 立即释放空间
- ✅ 可以选择保留最近的分区

---

### 🎯 方案4：按日志级别删除（减少数据量）⭐

**先删除占比最大的日志级别：**

#### 步骤1：查看各级别的数据量

```sql
SELECT 
    level,
    formatReadableQuantity(count()) AS records,
    round(count() * 100.0 / (SELECT count() FROM system.text_log), 2) AS percentage
FROM system.text_log
GROUP BY level
ORDER BY count DESC;
```

#### 步骤2：删除 Trace 和 Debug 日志（通常占比最大）

```sql
ALTER TABLE system.text_log DELETE WHERE level IN ('Trace', 'Debug');
```

#### 步骤3：等待几分钟后，删除 Information 日志

```sql
ALTER TABLE system.text_log DELETE WHERE level = 'Information';
```

#### 步骤4：只保留 Error 和 Warning

```sql
ALTER TABLE system.text_log DELETE WHERE level NOT IN ('Error', 'Warning');
```

---

## 🚀 完整执行流程（推荐）

### 情况A：如果方案1可行（最快）

```sql
-- 1. 直接清空（5秒搞定）
TRUNCATE TABLE system.text_log SETTINGS max_table_size_to_drop = 0;

-- 2. 验证结果
SELECT formatReadableSize(total_bytes) AS size 
FROM system.tables 
WHERE database = 'system' AND name = 'text_log';
```

### 情况B：如果方案1不可行（使用方案2+4组合）

```sql
-- 1. 先查看数据分布
SELECT 
    event_date,
    level,
    formatReadableQuantity(count()) AS records
FROM system.text_log
GROUP BY event_date, level
ORDER BY event_date DESC, count DESC
LIMIT 50;

-- 2. 删除 Trace 和 Debug（通常占比80%+）
ALTER TABLE system.text_log DELETE WHERE level IN ('Trace', 'Debug');

-- 3. 等待5分钟，检查进度
SELECT formatReadableSize(total_bytes) AS current_size 
FROM system.tables 
WHERE database = 'system' AND name = 'text_log';

-- 4. 删除90天前的数据
ALTER TABLE system.text_log DELETE WHERE event_date < today() - 90;

-- 5. 继续分批删除...
ALTER TABLE system.text_log DELETE WHERE event_date < today() - 60;

-- 6. 最后清空所有
ALTER TABLE system.text_log DELETE WHERE 1=1;

-- 7. 优化表释放空间
OPTIMIZE TABLE system.text_log FINAL;
```

---

## 📊 监控删除进度

### 查看当前表大小

```sql
SELECT 
    formatReadableSize(total_bytes) AS current_size,
    round(total_bytes / 1024 / 1024 / 1024, 2) AS size_gb
FROM system.tables
WHERE database = 'system' AND name = 'text_log';
```

### 查看正在执行的删除任务

```sql
SELECT 
    query,
    elapsed AS seconds_elapsed,
    formatReadableSize(read_bytes) AS processed
FROM system.processes
WHERE query LIKE '%text_log%';
```

### 查看磁盘空间变化

```sql
SELECT 
    name,
    path,
    formatReadableSize(free_space) AS free,
    formatReadableSize(total_space) AS total
FROM system.disks;
```

---

## ⚠️ 注意事项

### 关于 DELETE vs TRUNCATE

| 操作 | 速度 | 空间释放 | 可选择性 | 限制 |
|------|------|----------|---------|------|
| **TRUNCATE** | ⚡ 极快（秒级） | ✅ 立即释放 | ❌ 全部清空 | ⚠️ 有大小限制 |
| **DELETE** | 🐌 较慢（分钟/小时） | 🕐 延迟释放 | ✅ 可条件删除 | ✅ 无大小限制 |
| **DROP PARTITION** | ⚡ 快（秒级） | ✅ 立即释放 | ✅ 按分区删除 | ⚠️ 需要有分区 |

### 关于 DELETE 操作

- ✅ **异步执行**：DELETE 在后台执行，不会阻塞查询
- ⏰ **延迟生效**：空间可能不会立即释放，需要等待
- 🔄 **多次执行**：可以多次运行 DELETE，逐步减少数据
- 💾 **OPTIMIZE**：执行 `OPTIMIZE TABLE ... FINAL` 可加快空间释放

### 关于权限

如果遇到权限问题：
```
Code: 497. DB::Exception: ... Not enough privileges
```

需要联系 ClickHouse 管理员授予以下权限：
- `ALTER DELETE` - 用于 DELETE 操作
- `DROP TABLE` - 用于 TRUNCATE 操作
- `DROP PARTITION` - 用于删除分区

---

## ✅ 成功标志

当你看到这样的结果时，说明清理成功：

```sql
SELECT formatReadableSize(total_bytes) AS size 
FROM system.tables 
WHERE database = 'system' AND name = 'text_log';

-- 期望结果：
-- size
-- 0 B         （如果完全清空）
-- 或 < 1 GB   （如果保留了最近的数据）
```

---

## 🎯 我的推荐

**基于你的情况（413.21 GB text_log，只有数据库权限）：**

1. **首选**：尝试方案1，使用 `SETTINGS max_table_size_to_drop = 0`
2. **备选**：如果方案1不行，使用方案2或3分批删除
3. **最稳妥**：先删除 Trace/Debug 级别日志，再按日期分批删除
4. **清理后**：记得配置日志保留策略，防止再次累积

需要我帮你生成具体的执行脚本吗？
