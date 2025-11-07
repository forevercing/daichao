# ClickHouse 系统日志表管理工具集

## 📚 文档索引

本工具集包含了管理 ClickHouse 系统日志表的完整解决方案。

---

## 🎯 快速导航

### 如果你想...

| 需求 | 推荐文件 |
|------|---------|
| **查看所有表的概览** | `simple_query.sql` |
| **清理 text_log（384GB）** | `SYSTEM_LOG_CLEANUP_GUIDE.md` |
| **解决 TRUNCATE 报错** | `TRUNCATE_ERROR_FIX.md` 或 `QUICK_REFERENCE.md` |
| **了解 trace_log/processors_profile_log/part_log** | `SYSTEM_TABLES_DETAILED_GUIDE.md` |
| **快速对比三个表** | `QUICK_COMPARISON.md` |
| **清理三个表** | `cleanup_three_tables.sql` |
| **查看所有系统日志表** | `all_system_logs_overview.sql` |

---

## 📁 文件列表和说明

### 📊 表概览查询

#### 1. `simple_query.sql` ⭐ 最常用
**用途**：查询所有表的基本信息（集群名称、表名、行数、占用空间）

**特点**：
- ✅ 最简单直接
- ✅ 包含单节点和跨集群查询方案
- ✅ 已修复中文别名语法错误

**使用场景**：
- 查看所有业务表的大小
- 了解数据分布情况
- 找出占用空间最大的表

---

#### 2. `quick_query.sql`
**用途**：一键完整查询脚本，包含多个分析步骤

**特点**：
- 查看集群列表
- 查看当前主机信息
- 查看本地表概览
- 精确统计（基于分区）
- 数据库级别汇总
- 总体统计

**使用场景**：
- 全面了解 ClickHouse 集群状态
- 生成完整的数据报告

---

#### 3. `clickhouse_tables_overview.sql`
**用途**：多种查询方案的集合

**包含**：
- 6种不同的查询方案
- 本地表查询
- 跨集群查询
- 表类型判断

---

### 🧹 系统日志清理

#### 4. `SYSTEM_LOG_CLEANUP_GUIDE.md` ⭐ text_log 清理指南
**用途**：text_log 表的完整清理指南（针对你的 384GB 问题）

**包含**：
- text_log 是什么
- 为什么占用这么大空间
- 是否可以安全清理
- 详细的清理步骤
- 5种清理方案
- 配置自动清理
- 其他系统日志表的清理

**使用场景**：
- text_log 占用大量空间
- 需要释放磁盘空间

---

#### 5. `TRUNCATE_ERROR_FIX.md` ⭐ 解决 TRUNCATE 报错
**用途**：解决表大小超过 max_table_size_to_drop 限制的问题

**包含**：
- 4种解决方案
- 详细的执行步骤
- 监控删除进度的方法
- DELETE vs TRUNCATE 对比

**使用场景**：
- 执行 TRUNCATE 时报错：TABLE_SIZE_EXCEEDS_MAX_DROP_SIZE_LIMIT
- 表超过 50GB 无法删除

---

#### 6. `QUICK_REFERENCE.md` ⭐ 快速参考卡
**用途**：最精简的参考文档，快速查找命令

**特点**：
- 最快解决方案
- 备选方案
- 监控命令
- 推荐执行流程
- 常见问题

**使用场景**：
- 需要快速找到清理命令
- 不想看长文档

---

#### 7. `quick_cleanup.sql` - text_log 快速清理脚本
**用途**：text_log 的分步清理 SQL 脚本

**包含**：
- 查看当前状态
- 5种清理方法
- 验证清理效果
- 优化表
- 检查其他大型表

---

#### 8. `fix_truncate_error.sql` - TRUNCATE 报错修复脚本
**用途**：解决 TRUNCATE 报错的所有 SQL 方案

**包含**：
- 使用 SETTINGS 参数
- 按日期分批删除
- 按分区删除
- 按日志级别删除
- 验证删除进度

---

#### 9. `step_by_step_cleanup.sql` - 逐步清理脚本
**用途**：text_log 的详细分步执行脚本

**特点**：
- 每一步都有说明
- 包含检查命令
- 包含等待提示
- 适合新手按步骤执行

---

### 📖 三表详解（trace_log, processors_profile_log, part_log）

#### 10. `SYSTEM_TABLES_DETAILED_GUIDE.md` ⭐ 三表完整指南
**用途**：trace_log、processors_profile_log、part_log 的详细说明

**包含**：
- 每个表的详细介绍
- 表结构和字段说明
- 记录的信息
- 典型用途和示例查询
- 为什么会占用大量空间
- 是否可以清理
- 清理方法和建议
- 三表对比
- 配置 TTL 的方法

**使用场景**：
- 想深入了解这三个表
- 不确定是否应该清理
- 需要性能分析示例

**内容亮点**：
- 📊 详细的对比表格
- 💡 典型用途的 SQL 示例
- ⚠️ 清理优先级排序
- ⚙️ 配置文件示例

---

#### 11. `QUICK_COMPARISON.md` ⭐ 三表快速对比
**用途**：三个表的快速对比和清理决策

**特点**：
- 一句话总结
- 快速决策表
- 清理优先级
- 详细对比表格
- 典型场景的清理方案
- 长期解决方案

**使用场景**：
- 需要快速决定清理哪个表
- 不确定保留多久
- 想了解清理优先级

---

#### 12. `cleanup_three_tables.sql` - 三表清理脚本
**用途**：trace_log、processors_profile_log、part_log 的清理 SQL 脚本

**包含**：
- 6个步骤的完整流程
- 查看当前状态
- 多种清理方案
- 优化表
- 验证清理结果
- 检查其他系统表

---

#### 13. `system_tables_guide.sql` - 三表分析脚本
**用途**：分析三个表的详细信息

**包含**：
- 表大小和记录数
- 数据时间范围
- 类型/级别分布
- 分区情况
- 最近的记录
- 三表对比
- 汇总统计

**使用场景**：
- 深入分析三个表的数据
- 了解数据分布
- 决定清理策略

---

### 🔍 所有系统日志概览

#### 14. `all_system_logs_overview.sql` - 所有系统日志表概览
**用途**：查看所有 system 库中的日志表

**包含**：
- 所有日志表的大小和用途
- 系统日志表总占用空间
- TOP 10 最大的日志表
- 超过 1GB/10GB 的表
- 按类别分类统计
- 生成清理命令建议

**使用场景**：
- 全面了解系统日志表占用情况
- 找出所有需要清理的表
- 批量生成清理命令

---

### 📝 其他文档

#### 15. `README_CLICKHOUSE.md` - ClickHouse 表查询指南
**用途**：表概览查询的详细指南

**包含**：
- 4种查询方案
- 使用步骤
- 注意事项
- 常见问题
- 输出示例

---

#### 16. `QUICK_START.md` - 快速开始指南
**用途**：3步快速开始查询表信息

**包含**：
- 连接 ClickHouse
- 查看集群名称
- 执行查询（3个选项）
- 列名对照表
- 常见场景

---

#### 17. `index.php` - PHP 示例代码
**用途**：使用 PHP 连接 ClickHouse 并查询表信息

**特点**：
- HTTP 接口连接
- JSON 格式输出
- HTML 表格展示
- 汇总统计

---

#### 18. `README.md` - 本文件
**用途**：文档索引和导航

---

## 🚀 快速使用指南

### 场景1：查看所有表的大小

```bash
# 连接到 ClickHouse
clickhouse-client --host=your_host --user=your_user --password=your_password

# 执行查询
source /workspace/simple_query.sql
```

---

### 场景2：清理 text_log（384GB）

**步骤1**：先尝试最简单的方法
```sql
TRUNCATE TABLE system.text_log SETTINGS max_table_size_to_drop = 0;
```

**步骤2**：如果报错，使用分批删除
```sql
-- 删除 Trace 和 Debug 日志
ALTER TABLE system.text_log DELETE WHERE level IN ('Trace', 'Debug');

-- 等待5分钟，然后继续
ALTER TABLE system.text_log DELETE WHERE event_date < today() - 30;
```

📖 详细文档：`SYSTEM_LOG_CLEANUP_GUIDE.md` 或 `TRUNCATE_ERROR_FIX.md`

---

### 场景3：清理三个大表

**推荐清理顺序**：

```sql
-- 1. processors_profile_log（优先级最高）
TRUNCATE TABLE system.processors_profile_log SETTINGS max_table_size_to_drop = 0;

-- 2. trace_log（优先级中等）
TRUNCATE TABLE system.trace_log SETTINGS max_table_size_to_drop = 0;

-- 3. part_log（优先级低，保留30天）
ALTER TABLE system.part_log DELETE WHERE event_date < today() - 30;
```

📖 详细文档：`QUICK_COMPARISON.md` 或 `SYSTEM_TABLES_DETAILED_GUIDE.md`

---

### 场景4：查看所有系统日志表

```bash
# 执行完整的系统日志分析
source /workspace/all_system_logs_overview.sql
```

---

## 📊 关键表说明

| 表名 | 用途 | 典型大小 | 清理优先级 | 建议保留 |
|------|------|---------|-----------|---------|
| **text_log** | 文本日志 | 几十~几百GB | 中 | 7天 |
| **trace_log** | CPU/内存跟踪 | 几十GB | 中 | 7天 |
| **processors_profile_log** | 处理器性能 | 上百GB | **高** ⭐ | 3天 |
| **part_log** | 分区操作 | 几GB | 低 | 30天 |
| **query_log** | 查询日志 | 中等 | 低 | 30天 |

---

## ⚠️ 重要提示

1. **所有系统日志表都可以安全清理**，不会影响 ClickHouse 正常运行
2. **清理后会继续记录新日志**，不用担心
3. **TRUNCATE vs DELETE**：
   - TRUNCATE：快速清空，但有大小限制（50GB）
   - DELETE：较慢，但无大小限制，可条件删除
4. **清理优先级**：
   - 第一优先：processors_profile_log（最容易膨胀）
   - 第二优先：trace_log 和 text_log
   - 第三优先：part_log（相对重要）
5. **长期解决方案**：配置 TTL 自动清理

---

## 🔧 配置自动清理（推荐）

编辑配置文件 `/etc/clickhouse-server/config.d/logs_ttl.xml`：

```xml
<clickhouse>
    <!-- text_log: 保留7天 -->
    <text_log>
        <ttl>event_date + INTERVAL 7 DAY</ttl>
    </text_log>
    
    <!-- trace_log: 保留7天 -->
    <trace_log>
        <ttl>event_date + INTERVAL 7 DAY</ttl>
    </trace_log>
    
    <!-- processors_profile_log: 保留3天 -->
    <processors_profile_log>
        <ttl>event_date + INTERVAL 3 DAY</ttl>
    </processors_profile_log>
    
    <!-- part_log: 保留30天 -->
    <part_log>
        <ttl>event_date + INTERVAL 30 DAY</ttl>
    </part_log>
</clickhouse>
```

**注意**：需要服务器权限才能修改配置文件。

---

## 📞 需要帮助？

### 按问题类型查找文档

| 问题 | 查看文档 |
|------|---------|
| text_log 占用 384GB | `SYSTEM_LOG_CLEANUP_GUIDE.md` |
| TRUNCATE 报错：表太大 | `TRUNCATE_ERROR_FIX.md` |
| 不知道该清理哪个表 | `QUICK_COMPARISON.md` |
| 想了解三个表的详细信息 | `SYSTEM_TABLES_DETAILED_GUIDE.md` |
| 需要快速清理命令 | `QUICK_REFERENCE.md` |
| 查看所有表的大小 | `simple_query.sql` |
| 查看所有系统日志 | `all_system_logs_overview.sql` |

---

## ✅ 快速检查清单

### 清理前：
- [ ] 已了解要清理的表的用途
- [ ] 已确认不需要历史数据
- [ ] 已选择合适的保留期限
- [ ] 已准备好清理命令

### 清理后：
- [ ] 表大小已减小
- [ ] ClickHouse 服务正常
- [ ] 新日志继续记录
- [ ] 磁盘空间已释放

---

## 🎯 推荐阅读顺序

### 如果你是新手：
1. 先看 `README.md`（本文件）了解全貌
2. 使用 `simple_query.sql` 查看所有表
3. 阅读 `QUICK_REFERENCE.md` 快速参考
4. 根据需要查看详细指南

### 如果你需要清理 text_log：
1. `QUICK_REFERENCE.md` - 找到快速命令
2. `TRUNCATE_ERROR_FIX.md` - 如果遇到报错
3. `SYSTEM_LOG_CLEANUP_GUIDE.md` - 详细指南

### 如果你想了解系统日志表：
1. `QUICK_COMPARISON.md` - 快速对比
2. `SYSTEM_TABLES_DETAILED_GUIDE.md` - 深入了解
3. `all_system_logs_overview.sql` - 查看所有表

---

## 📈 预期效果

执行清理后，你可能释放：
- **text_log**：~384 GB
- **processors_profile_log**：可能 50-200 GB
- **trace_log**：可能 20-100 GB
- **其他日志表**：几 GB 到几十 GB

**总计可能释放**：**几百 GB 到 1TB+** 的空间！

---

## 🌟 最佳实践

1. **定期检查**：每月检查一次系统日志表的大小
2. **配置 TTL**：设置自动清理，一劳永逸
3. **监控告警**：当系统日志表超过一定大小时告警
4. **保留策略**：
   - processors_profile_log：3天
   - trace_log：7天
   - text_log：7天
   - part_log：30天
   - query_log：30天
5. **清理优先级**：优先清理 processors_profile_log

---

**最后更新**：2025-11-07

**版本**：1.0

**作者**：AI Assistant

**License**：免费使用，无限制
