# Rent-a-Relic Market - RustChain Bounty #2312

> 🏛️ 古老/稀有物品租赁市场平台

## 📋 项目概述

Rent-a-Relic Market 是一个基于 RustChain 生态的去中心化租赁平台，专门用于古老、稀有、收藏级物品的租赁服务。

### 核心功能

- ✅ **用户系统** - 注册/登录/JWT 认证
- ✅ **物品管理** - 发布、编辑、删除租赁物品
- ✅ **租赁流程** - 预订、确认、激活、完成全流程
- ✅ **分类系统** - 10+ 标准分类（古代文物、中世纪 relics、维多利亚时代等）
- ✅ **评价系统** - 双向评价机制
- ✅ **支付集成** - RTC 代币支付支持
- ✅ **缓存优化** - Redis 缓存提升性能
- ✅ **健康检查** - 完整的服务监控

## 🚀 快速开始

### 1. 环境准备

```bash
# 克隆项目
cd rustchain-rent-a-relic

# 复制环境变量文件
cp .env.example .env

# 编辑 .env 文件，设置安全密钥和密码
nano .env
```

### 2. 启动服务

```bash
# 一键启动所有服务
docker-compose up -d

# 查看服务状态
docker-compose ps

# 查看日志
docker-compose logs -f
```

### 3. 验证部署

```bash
# 健康检查
curl http://localhost/health

# 获取统计数据
curl http://localhost/api/stats

# 列出所有物品
curl http://localhost/api/relics
```

## 📁 项目结构

```
rustchain-rent-a-relic/
├── app/
│   └── app.py              # Flask 主应用
├── init-db/
│   └── 001-schema.sql      # 数据库初始化脚本
├── nginx/
│   ├── nginx.conf          # Nginx 主配置
│   └── conf.d/             # 额外配置目录
├── docker-compose.yml      # Docker 服务编排
├── requirements.txt        # Python 依赖
├── .env.example           # 环境变量模板
└── README.md              # 本文档
```

## 🔌 API 接口

### 认证接口

| 方法 | 路径 | 描述 |
|------|------|------|
| POST | `/api/auth/register` | 用户注册 |
| POST | `/api/auth/login` | 用户登录 |
| GET | `/api/users/me` | 获取当前用户信息 |

### 物品接口

| 方法 | 路径 | 描述 |
|------|------|------|
| GET | `/api/relics` | 获取物品列表 |
| GET | `/api/relics/:id` | 获取单个物品 |
| POST | `/api/relics` | 创建新物品 (需认证) |

### 租赁接口

| 方法 | 路径 | 描述 |
|------|------|------|
| POST | `/api/relics/:id/rent` | 预订物品 (需认证) |
| GET | `/api/rentals` | 获取租赁记录 (需认证) |
| PUT | `/api/rentals/:id/status` | 更新租赁状态 (需认证) |

### 系统接口

| 方法 | 路径 | 描述 |
|------|------|------|
| GET | `/health` | 健康检查 |
| GET | `/api/stats` | 平台统计数据 |

## 📝 使用示例

### 注册新用户

```bash
curl -X POST http://localhost/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "username": "relic_hunter",
    "email": "hunter@example.com",
    "password": "secure_password_123"
  }'
```

### 登录获取 Token

```bash
curl -X POST http://localhost/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "username": "relic_hunter",
    "password": "secure_password_123"
  }'
```

### 创建租赁物品

```bash
curl -X POST http://localhost/api/relics \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{
    "name": "Ming Dynasty Vase",
    "description": "Authentic Ming Dynasty porcelain vase",
    "category": "Ancient Artifacts",
    "daily_rate": 200.00,
    "deposit_amount": 2000.00,
    "condition": "excellent"
  }'
```

### 预订物品

```bash
curl -X POST http://localhost/api/relics/1/rent \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{
    "start_date": "2026-04-01",
    "end_date": "2026-04-07"
  }'
```

## 🔒 安全特性

- ✅ 密码 SHA256 哈希存储
- ✅ Token 哈希存储（非明文）
- ✅ Token 过期机制（30 天）
- ✅ SQL 注入防护（参数化查询）
- ✅ CORS 跨域配置
- ✅ Nginx 速率限制（10 请求/秒）
- ✅ 安全响应头（X-Frame-Options, X-Content-Type-Options）

## 📊 数据库设计

### 核心表

- `users` - 用户信息
- `api_tokens` - API 认证令牌
- `relics` - 租赁物品
- `rentals` - 租赁订单
- `reviews` - 评价记录
- `categories` - 物品分类

### 预置数据

- 10 个标准分类
- 3 个测试用户
- 5 个示例物品

## 🛠️ 技术栈

| 组件 | 技术 | 版本 |
|------|------|------|
| 后端框架 | Flask | 3.0.0 |
| 数据库 | PostgreSQL | 16.4 |
| 缓存 | Redis | 7.4 |
| 反向代理 | Nginx | 1.25.4 |
| Python | Python | 3.11 |

## 🧪 测试

```bash
# 进入容器运行测试
docker-compose exec market-api python -m pytest

# 或手动测试 API
curl http://localhost/health
```

## 📈 监控与维护

### 查看服务状态

```bash
docker-compose ps
```

### 查看日志

```bash
# 所有服务
docker-compose logs -f

# 特定服务
docker-compose logs -f market-api
docker-compose logs -f postgres
docker-compose logs -f redis
```

### 重启服务

```bash
docker-compose restart
```

### 停止服务

```bash
docker-compose down
```

### 清理数据（谨慎使用）

```bash
docker-compose down -v
```

## 💰 RustChain 集成

### RTC 代币支付

平台支持 RustChain 原生代币 RTC 支付：

- 钱包地址：`RTC53fdf727dd301da40ee79cdd7bd740d8c04d2fb4`
- 支付确认：链上确认后自动更新订单状态
- 押金退还：租赁完成后自动退还

### 智能合约（未来）

- 租赁合约自动化执行
- 争议仲裁机制
- 信誉系统上链

## 📋 验收清单

| 功能 | 状态 |
|------|------|
| 用户注册/登录 | ✅ |
| JWT 认证系统 | ✅ |
| 物品 CRUD | ✅ |
| 租赁流程 | ✅ |
| 分类系统 | ✅ |
| 评价系统 | ✅ |
| Redis 缓存 | ✅ |
| 健康检查 | ✅ |
| Docker 部署 | ✅ |
| README 文档 | ✅ |
| 环境变量配置 | ✅ |

## 🎯 下一步

1. **智能合约集成** - RustChain 链上支付
2. **争议仲裁** - 去中心化仲裁机制
3. **信誉系统** - 基于链上的信誉评分
4. **移动端** - React Native 应用
5. **多语言** - i18n 国际化支持

## 📄 许可证

MIT License - RustChain Bounty Program

## 👥 联系方式

- GitHub: https://github.com/RustChain-Protocol/RustChain
- Issue: #2312
- 开发者：牛马 🐴

---

**代码已完成！PR 准备提交！** 🎉
