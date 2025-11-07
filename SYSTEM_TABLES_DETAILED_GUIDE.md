# ClickHouse 系统日志表详解

## 📊 概览对比

| 表名 | 用途 | 记录内容 | 典型大小 | 是否可清理 | 对性能影响 |
|------|------|----------|---------|-----------|-----------|
| **trace_log** | 查询跟踪 | CPU采样、查询执行栈 | 大（几十GB+） | ✅ 可以 | 中等 |
| **processors_profile_log** | 处理器性能 | 查询处理器的详细性能指标 | 很大（可能上百GB） | ✅ 可以 | 高 |
| **part_log** | 分区操作 | 数据分区的创建、合并、删除 | 中等（几GB） | ✅ 可以 | 低 |

---

## 1️⃣ trace_log - 查询跟踪日志表

### 📋 是什么？

**trace_log** 记录查询执行时的**栈跟踪信息**，主要用于性能分析和调试。

### 🔍 记录的信息

- **CPU 采样数据**：查询执行时的 CPU 使用情况
- **函数调用栈**：查询执行过程中调用的函数堆栈
- **线程信息**：执行查询的线程 ID
- **查询 ID**：关联到具体的查询
- **时间戳**：采样时间

### 📊 表结构关键字段

| 字段 | 说明 |
|------|------|
| event_date | 事件日期 |
| event_time | 事件时间 |
| timestamp_ns | 纳秒级时间戳 |
| thread_id | 线程 ID |
| query_id | 查询 ID |
| trace_type | 跟踪类型（CPU、Real、Memory等） |
| trace | 函数调用栈数组 |
| size | 内存分配大小 |

### 🎯 什么时候会记录？

- 当配置了查询性能分析（query profiler）时
- 执行复杂查询时
- 开启了内存分析或 CPU 分析时

### 📈 典型用途

**1. 分析慢查询的瓶颈**
```sql
-- 找出某个查询的 CPU 热点
SELECT 
    arrayStringConcat(arrayMap(x -> demangle(addressToSymbol(x)), trace), '\n') AS stack,
    count() AS samples
FROM system.trace_log
WHERE query_id = 'your-query-id'
  AND trace_type = 'CPU'
GROUP BY stack
ORDER BY samples DESC
LIMIT 10;
```

**2. 分析内存使用**
```sql
-- 查看内存分配热点
SELECT 
    arrayStringConcat(arrayMap(x -> demangle(addressToSymbol(x)), trace), '\n') AS stack,
    sum(size) AS total_allocated
FROM system.trace_log
WHERE trace_type = 'Memory'
  AND event_date = today()
GROUP BY stack
ORDER BY total_allocated DESC
LIMIT 10;
```

### ⚠️ 为什么会占用大量空间？

- **高频率采样**：默认每秒采样多次
- **复杂查询多**：查询越复杂，调用栈越深，数据越多
- **调用栈深度**：每个采样包含完整的函数调用栈
- **没有定期清理**：日志无限累积

### ✅ 是否可以清理？

**完全可以！**

- ✅ 这是历史性能分析数据
- ✅ 清理不影响 ClickHouse 运行
- ✅ 只影响历史性能分析
- ⚠️ 如果正在进行性能调优，建议保留最近几天的数据

### 🧹 如何清理？

**完全清空：**
```sql
-- 方法1：使用 SETTINGS 参数
TRUNCATE TABLE system.trace_log SETTINGS max_table_size_to_drop = 0;

-- 方法2：如果方法1不行，删除所有数据
ALTER TABLE system.trace_log DELETE WHERE 1=1;
```

**保留最近7天：**
```sql
ALTER TABLE system.trace_log DELETE WHERE event_date < today() - 7;
```

**按跟踪类型清理（只保留 CPU 和 Memory）：**
```sql
ALTER TABLE system.trace_log DELETE WHERE trace_type NOT IN ('CPU', 'Memory');
```

---

## 2️⃣ processors_profile_log - 查询处理器性能日志表

### 📋 是什么？

**processors_profile_log** 记录查询执行过程中每个**处理器（Processor）**的详细性能指标。

### 🔍 记录的信息

- **处理器名称**：每个查询步骤的处理器名称
- **执行时间**：每个处理器的运行时间
- **输入/输出行数**：数据流量统计
- **内存使用**：处理器的内存消耗
- **CPU 时间**：实际 CPU 使用时间
- **等待时间**：IO 或其他等待时间

### 📊 表结构关键字段

| 字段 | 说明 |
|------|------|
| event_date | 事件日期 |
| event_time | 事件时间 |
| id | 处理器 ID |
| parent_ids | 父处理器 ID 数组 |
| plan_step | 查询计划步骤 |
| plan_group | 查询计划组 |
| name | 处理器名称 |
| elapsed_us | 运行时间（微秒） |
| input_wait_elapsed_us | 输入等待时间 |
| output_wait_elapsed_us | 输出等待时间 |
| input_rows | 输入行数 |
| input_bytes | 输入字节数 |
| output_rows | 输出行数 |
| output_bytes | 输出字节数 |

### 🎯 什么时候会记录？

- 当启用了处理器性能分析时（配置参数：log_processors_profiles）
- **每个查询**都会记录其所有处理器的性能数据
- 记录频率非常高，数据量增长迅速

### 📈 典型用途

**1. 分析查询的详细执行流程**
```sql
-- 查看某个查询的处理器执行时间分布
SELECT 
    name,
    count() AS count,
    round(sum(elapsed_us) / 1000000, 2) AS total_seconds,
    round(avg(elapsed_us) / 1000, 2) AS avg_ms
FROM system.processors_profile_log
WHERE query_id = 'your-query-id'
GROUP BY name
ORDER BY total_seconds DESC;
```

**2. 找出最慢的处理器**
```sql
-- 找出执行时间最长的处理器
SELECT 
    query_id,
    name,
    round(elapsed_us / 1000000, 2) AS seconds,
    input_rows,
    output_rows
FROM system.processors_profile_log
WHERE event_date = today()
ORDER BY elapsed_us DESC
LIMIT 20;
```

**3. 分析 IO 等待**
```sql
-- 找出 IO 等待时间最长的查询
SELECT 
    query_id,
    name,
    round((input_wait_elapsed_us + output_wait_elapsed_us) / 1000000, 2) AS wait_seconds
FROM system.processors_profile_log
WHERE event_date = today()
ORDER BY wait_seconds DESC
LIMIT 20;
```

### ⚠️ 为什么会占用大量空间？

- **极高的记录频率**：每个查询可能产生几十到上百条记录
- **查询量大**：如果系统查询频繁，数据增长极快
- **详细的性能数据**：每条记录包含大量性能指标
- **最容易膨胀**：这是**最容易占用大量空间的系统表**

### 💡 性能影响

- ⚠️ **对性能影响最大**的系统日志表
- 记录日志本身会消耗 CPU 和 IO
- 如果不需要详细的性能分析，建议关闭或定期清理

### ✅ 是否可以清理？

**强烈建议清理！**

- ✅ 除非正在进行性能调优，否则可以完全清空
- ✅ 清理可以显著提升整体性能
- ✅ 清理后系统会继续记录新的日志
- ⚠️ 如果需要性能分析，保留最近1-3天即可

### 🧹 如何清理？

**完全清空（推荐）：**
```sql
-- 方法1：使用 SETTINGS 参数
TRUNCATE TABLE system.processors_profile_log SETTINGS max_table_size_to_drop = 0;

-- 方法2：如果方法1不行
ALTER TABLE system.processors_profile_log DELETE WHERE 1=1;
```

**保留最近3天：**
```sql
ALTER TABLE system.processors_profile_log DELETE WHERE event_date < today() - 3;
```

**分批删除（如果表很大）：**
```sql
-- 先删除30天前的
ALTER TABLE system.processors_profile_log DELETE WHERE event_date < today() - 30;
-- 等待5分钟
ALTER TABLE system.processors_profile_log DELETE WHERE event_date < today() - 7;
-- 等待5分钟
ALTER TABLE system.processors_profile_log DELETE WHERE event_date < today() - 3;
```

### 🔧 如何禁用（减少未来的空间占用）

在配置文件中设置：

```xml
<clickhouse>
    <!-- 完全禁用 -->
    <processors_profile_log remove="1"/>
    
    <!-- 或设置较短的保留期 -->
    <processors_profile_log>
        <database>system</database>
        <table>processors_profile_log</table>
        <ttl>event_date + INTERVAL 3 DAY</ttl>
    </processors_profile_log>
</clickhouse>
```

---

## 3️⃣ part_log - 数据分区操作日志表

### 📋 是什么？

**part_log** 记录所有表的**数据分区（part）操作**，包括创建、合并、删除等。

### 🔍 记录的信息

- **分区操作类型**：NewPart、MergeParts、DownloadPart、RemovePart 等
- **操作的表**：数据库名和表名
- **分区名称**：具体的分区标识
- **操作耗时**：操作花费的时间
- **数据大小**：分区的行数和字节数
- **错误信息**：如果操作失败，记录错误

### 📊 表结构关键字段

| 字段 | 说明 |
|------|------|
| event_date | 事件日期 |
| event_time | 事件时间 |
| duration_ms | 操作持续时间（毫秒） |
| database | 数据库名 |
| table | 表名 |
| part_name | 分区名称 |
| partition_id | 分区 ID |
| event_type | 事件类型 |
| merge_reason | 合并原因（如果是合并操作） |
| rows | 行数 |
| size_in_bytes | 字节数 |
| merged_from | 合并来源（分区列表） |
| error | 错误信息（如果失败） |

### 🎯 什么时候会记录？

- **插入数据**时（NewPart）
- **分区合并**时（MergeParts）
- **分区下载**时（DownloadPart，复制表）
- **分区删除**时（RemovePart）
- **分区移动**时（MovePart）

### 📈 事件类型说明

| 事件类型 | 说明 | 常见程度 |
|---------|------|---------|
| **NewPart** | 创建新分区 | 极高 - 每次插入 |
| **MergeParts** | 合并分区 | 高 - 后台自动合并 |
| **DownloadPart** | 下载分区（复制表） | 中 - 有复制时 |
| **RemovePart** | 删除分区 | 中 - TTL或手动删除 |
| **MovePart** | 移动分区 | 低 |
| **MutatePart** | 修改分区（ALTER） | 低 |

### 📈 典型用途

**1. 分析表的写入频率**
```sql
-- 查看每个表的插入次数（最近7天）
SELECT 
    database,
    table,
    count() AS insert_count,
    sum(rows) AS total_rows_inserted
FROM system.part_log
WHERE event_type = 'NewPart'
  AND event_date >= today() - 7
GROUP BY database, table
ORDER BY insert_count DESC
LIMIT 20;
```

**2. 分析合并性能**
```sql
-- 查看最慢的合并操作
SELECT 
    database,
    table,
    part_name,
    round(duration_ms / 1000, 2) AS duration_seconds,
    rows,
    formatReadableSize(size_in_bytes) AS size
FROM system.part_log
WHERE event_type = 'MergeParts'
  AND event_date >= today() - 7
ORDER BY duration_ms DESC
LIMIT 20;
```

**3. 监控失败的操作**
```sql
-- 查看失败的分区操作
SELECT 
    event_time,
    database,
    table,
    event_type,
    error
FROM system.part_log
WHERE error != ''
  AND event_date >= today() - 7
ORDER BY event_time DESC;
```

**4. 统计表的合并频率**
```sql
-- 查看哪些表合并最频繁
SELECT 
    database,
    table,
    count() AS merge_count,
    round(avg(duration_ms) / 1000, 2) AS avg_duration_seconds
FROM system.part_log
WHERE event_type = 'MergeParts'
  AND event_date >= today() - 7
GROUP BY database, table
ORDER BY merge_count DESC;
```

### ⚠️ 为什么会占用大量空间？

- **高频写入的表**：频繁插入导致大量 NewPart 记录
- **小批量插入**：每次小批量插入都会产生一条记录
- **频繁合并**：后台合并产生 MergeParts 记录
- **复制表**：主从复制产生 DownloadPart 记录
- **长时间累积**：如果从未清理

### ✅ 是否可以清理？

**可以清理，但需要谨慎！**

- ✅ 历史操作日志可以清理
- ⚠️ 如果需要审计分区操作历史，建议保留一段时间
- ⚠️ 如果在排查数据问题，建议保留最近的数据
- ✅ 对于正常运行的系统，保留7-30天即可

### 💡 建议保留时间

- **生产环境**：保留 30 天（用于问题排查）
- **开发环境**：保留 7 天
- **如果空间紧张**：保留 3 天

### 🧹 如何清理？

**保留最近30天（推荐）：**
```sql
ALTER TABLE system.part_log DELETE WHERE event_date < today() - 30;
```

**保留最近7天：**
```sql
ALTER TABLE system.part_log DELETE WHERE event_date < today() - 7;
```

**完全清空（不推荐）：**
```sql
-- 方法1：使用 SETTINGS 参数
TRUNCATE TABLE system.part_log SETTINGS max_table_size_to_drop = 0;

-- 方法2：如果方法1不行
ALTER TABLE system.part_log DELETE WHERE 1=1;
```

**只删除 NewPart 类型（保留重要的合并记录）：**
```sql
-- NewPart 记录最多，但价值较低
ALTER TABLE system.part_log DELETE WHERE event_type = 'NewPart' AND event_date < today() - 7;
```

---

## 🎯 三表对比与清理建议

### 📊 重要性排序（从高到低）

1. **part_log** ⭐⭐⭐
   - **重要性**：高（用于问题排查和性能分析）
   - **建议**：保留 30 天
   - **清理优先级**：低

2. **trace_log** ⭐⭐
   - **重要性**：中（仅性能调优时有用）
   - **建议**：保留 7 天或完全清空
   - **清理优先级**：中

3. **processors_profile_log** ⭐
   - **重要性**：低（仅深度性能分析时有用）
   - **建议**：保留 3 天或完全清空
   - **清理优先级**：高（优先清理）

### 🧹 推荐的清理策略

**如果空间紧张，按此顺序清理：**

#### 第1步：清理 processors_profile_log（影响最小）
```sql
-- 完全清空或只保留3天
ALTER TABLE system.processors_profile_log DELETE WHERE event_date < today() - 3;
```

#### 第2步：清理 trace_log
```sql
-- 保留7天
ALTER TABLE system.trace_log DELETE WHERE event_date < today() - 7;
```

#### 第3步：清理 part_log（最后考虑）
```sql
-- 保留30天
ALTER TABLE system.part_log DELETE WHERE event_date < today() - 30;
```

### ⚙️ 长期解决方案：配置 TTL

在配置文件中设置自动清理：

```xml
<clickhouse>
    <!-- trace_log: 保留7天 -->
    <trace_log>
        <database>system</database>
        <table>trace_log</table>
        <ttl>event_date + INTERVAL 7 DAY</ttl>
    </trace_log>
    
    <!-- processors_profile_log: 保留3天 -->
    <processors_profile_log>
        <database>system</database>
        <table>processors_profile_log</table>
        <ttl>event_date + INTERVAL 3 DAY</ttl>
    </processors_profile_log>
    
    <!-- part_log: 保留30天 -->
    <part_log>
        <database>system</database>
        <table>part_log</table>
        <ttl>event_date + INTERVAL 30 DAY</ttl>
    </part_log>
</clickhouse>
```

---

## 📊 快速检查脚本

**一键查看所有三个表的大小：**
```sql
SELECT 
    name AS table_name,
    formatReadableSize(total_bytes) AS size,
    round(total_bytes / 1024 / 1024 / 1024, 2) AS size_gb,
    formatReadableQuantity(total_rows) AS records,
    CASE 
        WHEN name = 'trace_log' THEN '查询跟踪日志'
        WHEN name = 'processors_profile_log' THEN '处理器性能日志'
        WHEN name = 'part_log' THEN '分区操作日志'
    END AS description,
    CASE 
        WHEN name = 'processors_profile_log' THEN '高'
        WHEN name = 'trace_log' THEN '中'
        WHEN name = 'part_log' THEN '低'
    END AS cleanup_priority
FROM system.tables
WHERE database = 'system' 
  AND name IN ('trace_log', 'processors_profile_log', 'part_log')
ORDER BY total_bytes DESC;
```

---

## ✅ 总结

| 表 | 用途 | 是否可清理 | 建议保留 | 清理优先级 |
|----|------|----------|---------|-----------|
| **trace_log** | 查询性能分析 | ✅ 是 | 7天 | 中 |
| **processors_profile_log** | 详细性能分析 | ✅ 是 | 3天 | **高** ⭐ |
| **part_log** | 分区操作审计 | ⚠️ 谨慎 | 30天 | 低 |

**关键建议**：
1. **processors_profile_log** 是最容易膨胀的，优先清理
2. **trace_log** 除非在做性能调优，否则可以完全清空
3. **part_log** 相对重要，建议至少保留7-30天用于问题排查
4. 所有日志表都可以安全清理，不影响 ClickHouse 正常运行
5. 配置 TTL 是长期解决方案
