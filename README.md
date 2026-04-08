# RustChain 创始矿工 - 挖矿仪表盘与奖励管理系统

**问题**: rustchain-bounties #2451  
**奖励**: ~75 RTC  
**状态**: ✅ 已完成

## 📋 概述

创始矿工是一个全面的挖矿仪表盘和奖励管理系统，专为 RustChain 设计。它为矿工提供工具来跟踪他们的挖矿会话、管理奖励和提取收益。

## ✨ 功能特性

### 核心功能
- **用户注册与认证** - 基于 JWT 的安全登录系统
- **挖矿会话管理** - 开始、跟踪和结束挖矿会话
- **奖励追踪** - 自动计算奖励并记录历史
- **提现系统** - 申请和追踪奖励提现
- **排行榜** - 全球顶级矿工排名
- **实时统计** - 挖矿性能指标

### 技术特性
- 基于 Flask 后端的 RESTful API
- PostgreSQL 数据库用于持久化存储
- Redis 缓存用于会话管理
- 带速率限制的 Nginx 反向代理
- Docker Compose 一键部署
- 健康检查端点
- 全面的 API 测试套件

## 📁 项目结构

```
rustchain-founding-miner/
├── app/
│   └── app.py              # Flask API 应用 (600+ 行)
├── init-db/
│   └── 001-schema.sql      # 数据库结构 + 示例数据
├── nginx/
│   ├── nginx.conf          # Nginx 主配置
│   └── conf.d/
│       └── founding-miner.conf  # API 代理配置
├── docker-compose.yml      # 服务编排
├── Dockerfile              # API 容器镜像
├── requirements.txt        # Python 依赖
├── .env.example           # 环境变量模板
├── test-api.sh            # API 测试脚本
└── README.md              # 本文件
```

## 🚀 快速开始

### 前提条件
- Docker 和 Docker Compose
- Git

### 1. 克隆与设置

```bash
# 克隆仓库
cd rustchain-founding-miner

# 复制环境文件
cp .env.example .env

# 编辑 .env 并设置您的 JWT_SECRET
# 重要：在生产环境中请更改默认密钥！
```

### 2. 使用 Docker Compose 部署

```bash
# 启动所有服务
docker-compose up -d

# 检查状态
docker-compose ps

# 查看日志
docker-compose logs -f api
```

### 3. 验证部署

```bash
# 健康检查
curl http://localhost:8080/api/health

# 预期响应:
# {"status":"healthy","database":"healthy","redis":"healthy",...}
```

### 4. 运行测试

```bash
# 运行 API 测试套件
./test-api.sh

# 或使用自定义基础 URL
BASE_URL=http://localhost:5000 ./test-api.sh
```

## 📖 API 文档

### 认证

#### 注册新矿工
```bash
POST /api/register
Content-Type: application/json

{
    "username": "miner123",
    "password": "securepassword",
    "wallet_address": "RTC1YourWalletAddress",
    "miner_name": "My Mining Rig"
}

响应:
{
    "message": "Registration successful",
    "user": { ... },
    "token": "eyJhbGc..."
}
```

#### 登录
```bash
POST /api/login
Content-Type: application/json

{
    "username": "miner123",
    "password": "securepassword"
}

响应:
{
    "message": "Login successful",
    "user": { ... },
    "token": "eyJhbGc..."
}
```

### 矿工仪表盘

#### 获取矿工统计
```bash
GET /api/miner/stats
Authorization: Bearer <token>

响应:
{
    "total_rewards": 240.5,
    "reward_count": 5,
    "total_sessions": 10,
    "total_mining_hours": 168.5,
    "recent_rewards": [...]
}
```

#### 开始挖矿会话
```bash
POST /api/miner/sessions
Authorization: Bearer <token>
Content-Type: application/json

{
    "miner_name": "Rig #1"
}

响应:
{
    "message": "Mining session started",
    "session": {
        "id": 1,
        "miner_name": "Rig #1",
        "start_time": "2026-03-26T10:00:00Z",
        "status": "active"
    }
}
```

#### 结束挖矿会话
```bash
POST /api/miner/sessions/<session_id>/end
Authorization: Bearer <token>
Content-Type: application/json

{
    "blocks_found": 5,
    "rewards_earned": 150.0
}
```

### 奖励

#### 获取奖励历史
```bash
GET /api/rewards?limit=50&offset=0
Authorization: Bearer <token>

响应:
{
    "rewards": [...],
    "total": 25,
    "limit": 50,
    "offset": 0
}
```

#### 申请提现
```bash
POST /api/rewards/withdraw
Authorization: Bearer <token>
Content-Type: application/json

{
    "amount": 100.0,
    "wallet_address": "RTC1YourWalletAddress"
}
```

#### 获取提现历史
```bash
GET /api/withdrawals
Authorization: Bearer <token>
```

### 排行榜

#### 获取全球排行榜
```bash
GET /api/leaderboard?limit=10

响应:
{
    "leaderboard": [
        {
            "id": 1,
            "username": "top_miner",
            "miner_name": "Elite Rig",
            "total_sessions": 50,
            "total_blocks": 250,
            "total_rewards": 7500.0
        },
        ...
    ]
}
```

### 系统

#### 健康检查
```bash
GET /api/health

响应:
{
    "status": "healthy",
    "database": "healthy",
    "redis": "healthy",
    "timestamp": "2026-03-26T10:32:00Z"
}
```

## 🔧 配置

### 环境变量

| 变量 | 描述 | 默认值 |
|----------|-------------|---------|
| `JWT_SECRET` | JWT 令牌的密钥 | (必须设置) |
| `DATABASE_URL` | PostgreSQL 连接字符串 | 自动配置 |
| `REDIS_URL` | Redis 连接字符串 | 自动配置 |
| `NGINX_PORT` | Nginx 暴露端口 | 8080 |

### 数据库结构

系统使用 5 个主要表：
- `users` - 矿工账户
- `mining_sessions` - 活跃/已完成的挖矿会话
- `rewards` - 奖励记录
- `withdrawals` - 提现请求
- `pool_stats` - 矿池统计

## 🏗️ 架构

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   客户端    │────▶│   Nginx     │────▶│  Flask API  │
│  (浏览器/   │     │  (端口 80)  │     │ (端口 5000) │
│   移动端)   │     │  速率限制   │     │             │
└─────────────┘     └─────────────┘     └──────┬──────┘
                                               │
                    ┌──────────────────────────┼──────────────────────────┐
                    │                          │                          │
                    ▼                          ▼                          ▼
            ┌───────────────┐         ┌───────────────┐         ┌───────────────┐
            │   PostgreSQL  │         │     Redis     │         │   文件系统    │
            │   (端口 5432) │         │   (端口 6379) │         │   (卷)        │
            │   16.4-alpine │         │    7.4-alpine │         │               │
            └───────────────┘         └───────────────┘         └───────────────┘
```

## 🛡️ 安全特性

- **JWT 认证** - 带 30 天过期时间的令牌认证
- **密码哈希** - SHA-256 密码哈希
- **速率限制** - 每个 IP 每秒 10 个请求
- **连接限制** - 每个 IP 最多 10 个并发连接
- **安全头** - X-Frame-Options, X-Content-Type-Options 等
- **非 root 用户** - 应用以非特权用户运行
- **SQL 注入防护** - 参数化查询

## 📊 监控

### Docker Compose 日志
```bash
# 查看所有日志
docker-compose logs -f

# 查看特定服务
docker-compose logs -f api
```

### 健康端点
- API 健康: `http://localhost:8080/api/health`
- 数据库: 包含在 API 健康检查中
- Redis: 包含在 API 健康检查中

## 🧪 测试

### 运行测试套件
```bash
./test-api.sh
```

### 手动测试
```bash
# 注册
curl -X POST http://localhost:8080/api/register \
  -H "Content-Type: application/json" \
  -d '{"username":"test","password":"test123","wallet_address":"RTC1Test","miner_name":"Test"}'

# 登录
curl -X POST http://localhost:8080/api/login \
  -H "Content-Type: application/json" \
  -d '{"username":"test","password":"test123"}'
```

## 📝 开发

### 本地开发
```bash
# 构建并启动
docker-compose up --build

# 重建特定服务
docker-compose up --build api

# 停止所有服务
docker-compose down

# 停止并删除卷
docker-compose down -v
```

### 数据库访问
```bash
# 连接到 PostgreSQL
docker exec -it founding-miner-postgres psql -U founding_miner -d founding_miner

# 连接到 Redis
docker exec -it founding-miner-redis redis-cli
```

## 📦 交付文件

| 文件 | 描述 |
|------|-------------|
| `app/app.py` | Flask API (600+ 行) |
| `docker-compose.yml` | 服务编排 |
| `Dockerfile` | API 容器镜像 |
| `init-db/001-schema.sql` | 数据库结构 |
| `nginx/nginx.conf` | Nginx 配置 |
| `nginx/conf.d/founding-miner.conf` | API 代理配置 |
| `requirements.txt` | Python 依赖 |
| `.env.example` | 环境变量模板 |
| `test-api.sh` | API 测试脚本 |
| `README.md` | 文档 |

## 💰 奖励领取

**钱包**: 参见 `.env` 或联系项目管理员  
**金额**: ~75 RTC  

## 📄 许可证

MIT 许可证 - 详见项目仓库。

## 🤝 支持

如有问题，请在此项目仓库提交 issue。

---

**为 RustChain Bounties 开发** 🦀  
**问题 #2451 - 创始矿工**