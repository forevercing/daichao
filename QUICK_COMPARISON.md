# 三表快速对比参考

## 📋 一句话总结

| 表名 | 一句话说明 |
|------|-----------|
| **trace_log** | 记录查询执行时的 CPU/内存采样，用于性能调优 |
| **processors_profile_log** | 记录每个查询处理器的详细性能指标，数据量最大 |
| **part_log** | 记录数据分区的创建、合并、删除等操作，用于审计 |

---

## ⚡ 快速决策表

### 我该清理哪个？

| 情况 | 建议清理的表 | 清理命令 |
|------|------------|---------|
| **空间非常紧张** | processors_profile_log（优先） | `TRUNCATE TABLE system.processors_profile_log SETTINGS max_table_size_to_drop = 0;` |
| **不做性能分析** | processors_profile_log + trace_log | 两个都 TRUNCATE |
| **需要保留审计记录** | 只清理 processors_profile_log 和 trace_log | part_log 保留30天 |
| **偶尔需要性能分析** | 保留最近3-7天即可 | `DELETE WHERE event_date < today() - 7;` |

---

## 🎯 清理优先级（从高到低）

### 1️⃣ processors_profile_log - **优先清理** ⚠️

**为什么优先？**
- ❌ 数据量最大（可能上百GB）
- ❌ 对性能影响最大
- ❌ 只在深度性能分析时有用
- ✅ 大部分情况下用不到

**建议保留**：3天（或完全清空）

**清理命令**：
```sql
-- 方法1：完全清空
TRUNCATE TABLE system.processors_profile_log SETTINGS max_table_size_to_drop = 0;

-- 方法2：保留3天
ALTER TABLE system.processors_profile_log DELETE WHERE event_date < today() - 3;
```

---

### 2️⃣ trace_log - **第二优先**

**为什么清理？**
- ⚠️ 数据量较大（几十GB）
- ⚠️ 只在性能调优时有用
- ✅ 除非在排查慢查询，否则用处不大

**建议保留**：7天（或完全清空）

**清理命令**：
```sql
-- 方法1：完全清空
TRUNCATE TABLE system.trace_log SETTINGS max_table_size_to_drop = 0;

-- 方法2：保留7天
ALTER TABLE system.trace_log DELETE WHERE event_date < today() - 7;
```

---

### 3️⃣ part_log - **最后考虑** ⚠️

**为什么谨慎？**
- ✅ 相对重要，用于问题排查
- ✅ 数据量相对较小
- ✅ 可以帮助理解数据分区行为
- ⚠️ 删除后无法追溯历史分区操作

**建议保留**：30天

**清理命令**：
```sql
-- 保留30天（推荐）
ALTER TABLE system.part_log DELETE WHERE event_date < today() - 30;

-- 或只删除 NewPart 类型（保留重要的合并记录）
ALTER TABLE system.part_log DELETE WHERE event_type = 'NewPart' AND event_date < today() - 7;
```

---

## 📊 详细对比表

| 特性 | trace_log | processors_profile_log | part_log |
|------|-----------|----------------------|----------|
| **用途** | CPU/内存采样分析 | 查询处理器性能分析 | 分区操作审计 |
| **数据量** | 大（几十GB） | 极大（上百GB） | 中等（几GB） |
| **记录频率** | 高（秒级采样） | 极高（每个查询多条） | 中（每次分区操作） |
| **性能影响** | 中等 | 高 | 低 |
| **使用频率** | 低（仅性能调优） | 极低（深度分析） | 中（问题排查） |
| **是否可清理** | ✅ 是 | ✅ 强烈建议 | ⚠️ 谨慎 |
| **建议保留** | 7天 | 3天 | 30天 |
| **清理优先级** | 中 | **高** ⭐ | 低 |
| **清理影响** | 无（除非正在性能调优） | 无（除非正在深度分析） | 小（历史审计丢失） |

---

## 🔍 如何判断该不该清理？

### trace_log

**可以完全清空的情况：**
- ✅ 系统运行正常
- ✅ 没有慢查询问题
- ✅ 不需要做性能分析

**建议保留的情况：**
- ⚠️ 正在排查慢查询
- ⚠️ 需要做性能调优
- ⚠️ 最近有性能问题

---

### processors_profile_log

**可以完全清空的情况：**（几乎总是）
- ✅ 不需要深度性能分析
- ✅ 系统运行正常
- ✅ 空间紧张

**建议保留的情况：**（极少）
- ⚠️ 正在进行详细的查询执行流程分析
- ⚠️ 需要优化特定查询的处理器性能

---

### part_log

**可以清理旧数据的情况：**
- ✅ 保留30天以上的数据
- ✅ 不需要长期审计

**不建议清理的情况：**
- ⚠️ 正在排查数据问题
- ⚠️ 需要审计分区操作历史
- ⚠️ 最近有数据异常

---

## 🎯 典型场景的清理方案

### 场景1：空间紧张，立即需要释放空间

```sql
-- 1. 清理 processors_profile_log（立即释放大量空间）
TRUNCATE TABLE system.processors_profile_log SETTINGS max_table_size_to_drop = 0;

-- 2. 清理 trace_log
TRUNCATE TABLE system.trace_log SETTINGS max_table_size_to_drop = 0;

-- 3. 清理 part_log（保留最近7天）
ALTER TABLE system.part_log DELETE WHERE event_date < today() - 7;
```

**预期效果**：可能释放 **几十到上百 GB** 空间

---

### 场景2：常规维护，保持系统健康

```sql
-- 1. processors_profile_log 保留3天
ALTER TABLE system.processors_profile_log DELETE WHERE event_date < today() - 3;

-- 2. trace_log 保留7天
ALTER TABLE system.trace_log DELETE WHERE event_date < today() - 7;

-- 3. part_log 保留30天
ALTER TABLE system.part_log DELETE WHERE event_date < today() - 30;
```

---

### 场景3：需要性能分析，但也要控制空间

```sql
-- 1. processors_profile_log 保留7天（足够分析最近的查询）
ALTER TABLE system.processors_profile_log DELETE WHERE event_date < today() - 7;

-- 2. trace_log 保留14天
ALTER TABLE system.trace_log DELETE WHERE event_date < today() - 14;

-- 3. part_log 保留60天
ALTER TABLE system.part_log DELETE WHERE event_date < today() - 60;
```

---

## ⚙️ 长期解决方案：配置自动清理

### 方法1：在配置文件中设置 TTL

编辑 `/etc/clickhouse-server/config.d/logs_ttl.xml`：

```xml
<clickhouse>
    <!-- processors_profile_log: 自动删除3天前的数据 -->
    <processors_profile_log>
        <database>system</database>
        <table>processors_profile_log</table>
        <ttl>event_date + INTERVAL 3 DAY</ttl>
    </processors_profile_log>
    
    <!-- trace_log: 自动删除7天前的数据 -->
    <trace_log>
        <database>system</database>
        <table>trace_log</table>
        <ttl>event_date + INTERVAL 7 DAY</ttl>
    </trace_log>
    
    <!-- part_log: 自动删除30天前的数据 -->
    <part_log>
        <database>system</database>
        <table>part_log</table>
        <ttl>event_date + INTERVAL 30 DAY</ttl>
    </part_log>
</clickhouse>
```

**注意**：需要重启 ClickHouse 服务才能生效。

### 方法2：完全禁用（如果完全不需要）

```xml
<clickhouse>
    <!-- 禁用 processors_profile_log -->
    <processors_profile_log remove="1"/>
    
    <!-- 禁用 trace_log -->
    <trace_log remove="1"/>
    
    <!-- 不建议禁用 part_log，它比较重要 -->
</clickhouse>
```

### 方法3：创建定期清理任务（cron）

```bash
# 编辑 crontab
crontab -e

# 每天凌晨2点自动清理
0 2 * * * clickhouse-client --query="ALTER TABLE system.processors_profile_log DELETE WHERE event_date < today() - 3"
0 2 * * * clickhouse-client --query="ALTER TABLE system.trace_log DELETE WHERE event_date < today() - 7"
0 2 * * * clickhouse-client --query="ALTER TABLE system.part_log DELETE WHERE event_date < today() - 30"
```

---

## 📊 一键检查脚本

**查看三个表的当前状态：**

```sql
SELECT 
    name AS table_name,
    formatReadableSize(total_bytes) AS size,
    round(total_bytes / 1024 / 1024 / 1024, 2) AS size_gb,
    formatReadableQuantity(total_rows) AS records,
    CASE 
        WHEN name = 'processors_profile_log' THEN '高'
        WHEN name = 'trace_log' THEN '中'
        WHEN name = 'part_log' THEN '低'
    END AS cleanup_priority,
    CASE 
        WHEN name = 'processors_profile_log' THEN '3天'
        WHEN name = 'trace_log' THEN '7天'
        WHEN name = 'part_log' THEN '30天'
    END AS recommended_retention
FROM system.tables
WHERE database = 'system' 
  AND name IN ('trace_log', 'processors_profile_log', 'part_log')
ORDER BY total_bytes DESC;
```

---

## ✅ 清理检查清单

执行清理前，确认：

- [ ] 已了解每个表的用途
- [ ] 已确认不需要历史性能数据
- [ ] 已选择合适的保留期限
- [ ] 已准备好清理命令
- [ ] 知道如何验证清理效果

执行清理后，验证：

- [ ] 表大小已减小
- [ ] ClickHouse 服务正常运行
- [ ] 新日志继续记录
- [ ] 磁盘空间已释放

---

## 🆘 常见问题

**Q1：清理这些表会影响 ClickHouse 运行吗？**
- A：不会。这些都是历史日志，清理后系统继续正常运行。

**Q2：哪个表最容易膨胀？**
- A：processors_profile_log，它可能占用上百GB。

**Q3：我应该保留多久的数据？**
- A：如果不做性能分析，完全清空都可以。常规建议：processors_profile_log 3天、trace_log 7天、part_log 30天。

**Q4：清理后空间没有立即释放怎么办？**
- A：DELETE 是异步操作，等待5-10分钟，或执行 `OPTIMIZE TABLE ... FINAL;`

**Q5：可以同时清理多个表吗？**
- A：可以，但建议逐个清理，每次清理后检查效果。

---

## 📁 相关文件

- `system_tables_guide.sql` - 三表分析查询脚本
- `cleanup_three_tables.sql` - 详细的清理脚本
- `SYSTEM_TABLES_DETAILED_GUIDE.md` - 完整的详细指南
- `QUICK_COMPARISON.md` - 本文件（快速参考）
