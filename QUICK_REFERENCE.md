# 快速参考：system.text_log 清理

## ⚡ 最快解决方案（推荐先试这个）

```sql
TRUNCATE TABLE system.text_log SETTINGS max_table_size_to_drop = 0;
```

**如果成功**：✅ 完成！空间立即释放。

**如果报错**：继续往下看 👇

---

## 🔄 备选方案：分批删除

### 方案A：按日志级别删除（推荐）⭐

```sql
-- 步骤1：删除 Trace 和 Debug（通常占 70-90%）
ALTER TABLE system.text_log DELETE WHERE level IN ('Trace', 'Debug');

-- 等待5分钟，检查大小
SELECT formatReadableSize(total_bytes) AS size 
FROM system.tables 
WHERE database = 'system' AND name = 'text_log';

-- 步骤2：如果还需要继续清理
ALTER TABLE system.text_log DELETE WHERE level = 'Information';

-- 步骤3：完全清空（如果需要）
ALTER TABLE system.text_log DELETE WHERE 1=1;
```

---

### 方案B：按日期分批删除

```sql
-- 逐步删除旧数据（每次等待5分钟）
ALTER TABLE system.text_log DELETE WHERE event_date < today() - 90;
-- 等待5分钟
ALTER TABLE system.text_log DELETE WHERE event_date < today() - 60;
-- 等待5分钟
ALTER TABLE system.text_log DELETE WHERE event_date < today() - 30;
-- 等待5分钟
ALTER TABLE system.text_log DELETE WHERE event_date < today() - 7;
```

---

### 方案C：按分区删除（如果有分区）

```sql
-- 1. 查看分区
SELECT partition, formatReadableSize(sum(bytes)) AS size
FROM system.parts
WHERE database = 'system' AND table = 'text_log' AND active = 1
GROUP BY partition
ORDER BY partition DESC;

-- 2. 删除旧分区（替换为实际的分区名）
ALTER TABLE system.text_log DROP PARTITION '202401';
ALTER TABLE system.text_log DROP PARTITION '202402';
-- 继续删除其他分区...
```

---

## 📊 监控命令

### 查看当前大小
```sql
SELECT 
    formatReadableSize(total_bytes) AS size,
    round(total_bytes / 1024 / 1024 / 1024, 2) AS size_gb
FROM system.tables
WHERE database = 'system' AND name = 'text_log';
```

### 查看数据分布
```sql
-- 按日志级别
SELECT level, count() AS count
FROM system.text_log
GROUP BY level
ORDER BY count DESC;

-- 按日期
SELECT event_date, count() AS count
FROM system.text_log
GROUP BY event_date
ORDER BY event_date DESC
LIMIT 10;
```

### 查看删除进度
```sql
SELECT query, elapsed, formatReadableSize(read_bytes) AS processed
FROM system.processes
WHERE query LIKE '%text_log%';
```

---

## 🎯 推荐执行流程

### 情况1：完全清空（最快）
```sql
-- 一条命令搞定
TRUNCATE TABLE system.text_log SETTINGS max_table_size_to_drop = 0;
```

### 情况2：保留最近7天
```sql
-- 1. 先删除 Trace/Debug
ALTER TABLE system.text_log DELETE WHERE level IN ('Trace', 'Debug');
-- 等待5分钟

-- 2. 删除7天前的数据
ALTER TABLE system.text_log DELETE WHERE event_date < today() - 7;
-- 等待5分钟

-- 3. 优化表
OPTIMIZE TABLE system.text_log FINAL;
```

### 情况3：只保留 Error 日志
```sql
-- 1. 删除非 Error 级别
ALTER TABLE system.text_log DELETE WHERE level != 'Error';
-- 等待5分钟

-- 2. 删除30天前的 Error
ALTER TABLE system.text_log DELETE WHERE event_date < today() - 30;
-- 等待5分钟

-- 3. 优化表
OPTIMIZE TABLE system.text_log FINAL;
```

---

## ⚠️ 常见问题

### Q1：DELETE 后空间没有立即释放？
**A**：DELETE 是异步操作，需要等待。执行 `OPTIMIZE TABLE system.text_log FINAL;` 可加速。

### Q2：报权限错误？
**A**：联系管理员授予 `ALTER DELETE` 或 `DROP TABLE` 权限。

### Q3：DELETE 很慢怎么办？
**A**：使用更小的时间范围，或按分区删除（如果有分区）。

### Q4：如何验证清理成功？
**A**：
```sql
SELECT formatReadableSize(total_bytes) AS size 
FROM system.tables 
WHERE database = 'system' AND name = 'text_log';
-- 应该看到 < 1 GB 或 0 B
```

---

## 📁 相关文件

- `step_by_step_cleanup.sql` - 详细的分步执行脚本
- `fix_truncate_error.sql` - 所有解决方案的SQL集合
- `TRUNCATE_ERROR_FIX.md` - 完整的修复指南
- `SYSTEM_LOG_CLEANUP_GUIDE.md` - 系统日志清理指南

---

## 🆘 紧急求助

如果所有方法都不行，可以：
1. 联系 ClickHouse 管理员
2. 请求创建 `/var/lib/clickhouse/flags/force_drop_table` 文件
3. 或请求临时提升权限

---

## ✅ 成功示例

**清理前**：
```
size_gb: 413.21
```

**清理后**：
```
size_gb: 0.05  （保留最近数据）
或
size_gb: 0     （完全清空）
```

**节省空间**：~413 GB ✨
