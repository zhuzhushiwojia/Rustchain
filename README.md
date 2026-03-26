# RustChain Founding Miner - Mining Dashboard & Reward Management

**Issue**: rustchain-bounties #2451  
**Reward**: ~75 RTC  
**Status**: ✅ Complete

## 📋 Overview

Founding Miner is a comprehensive mining dashboard and reward management system for RustChain. It provides miners with tools to track their mining sessions, manage rewards, and withdraw earnings.

## ✨ Features

### Core Functionality
- **User Registration & Authentication** - JWT-based secure login system
- **Mining Session Management** - Start, track, and end mining sessions
- **Reward Tracking** - Automatic reward calculation and history
- **Withdrawal System** - Request and track reward withdrawals
- **Leaderboard** - Global ranking of top miners
- **Real-time Statistics** - Mining performance metrics

### Technical Features
- RESTful API with Flask backend
- PostgreSQL database for persistent storage
- Redis caching for session management
- Nginx reverse proxy with rate limiting
- Docker Compose one-click deployment
- Health check endpoints
- Comprehensive API test suite

## 📁 Project Structure

```
rustchain-founding-miner/
├── app/
│   └── app.py              # Flask API application (600+ lines)
├── init-db/
│   └── 001-schema.sql      # Database schema + sample data
├── nginx/
│   ├── nginx.conf          # Nginx main configuration
│   └── conf.d/
│       └── founding-miner.conf  # API proxy config
├── docker-compose.yml      # Service orchestration
├── Dockerfile              # API container image
├── requirements.txt        # Python dependencies
├── .env.example           # Environment variables template
├── test-api.sh            # API test script
└── README.md              # This file
```

## 🚀 Quick Start

### Prerequisites
- Docker & Docker Compose
- Git

### 1. Clone & Setup

```bash
# Clone the repository
cd rustchain-founding-miner

# Copy environment file
cp .env.example .env

# Edit .env and set your JWT_SECRET
# IMPORTANT: Change the default secret in production!
```

### 2. Deploy with Docker Compose

```bash
# Start all services
docker-compose up -d

# Check status
docker-compose ps

# View logs
docker-compose logs -f api
```

### 3. Verify Deployment

```bash
# Health check
curl http://localhost:8080/api/health

# Expected response:
# {"status":"healthy","database":"healthy","redis":"healthy",...}
```

### 4. Run Tests

```bash
# Run API test suite
./test-api.sh

# Or with custom base URL
BASE_URL=http://localhost:5000 ./test-api.sh
```

## 📖 API Documentation

### Authentication

#### Register New Miner
```bash
POST /api/register
Content-Type: application/json

{
    "username": "miner123",
    "password": "securepassword",
    "wallet_address": "RTC1YourWalletAddress",
    "miner_name": "My Mining Rig"
}

Response:
{
    "message": "Registration successful",
    "user": { ... },
    "token": "eyJhbGc..."
}
```

#### Login
```bash
POST /api/login
Content-Type: application/json

{
    "username": "miner123",
    "password": "securepassword"
}

Response:
{
    "message": "Login successful",
    "user": { ... },
    "token": "eyJhbGc..."
}
```

### Miner Dashboard

#### Get Miner Statistics
```bash
GET /api/miner/stats
Authorization: Bearer <token>

Response:
{
    "total_rewards": 240.5,
    "reward_count": 5,
    "total_sessions": 10,
    "total_mining_hours": 168.5,
    "recent_rewards": [...]
}
```

#### Start Mining Session
```bash
POST /api/miner/sessions
Authorization: Bearer <token>
Content-Type: application/json

{
    "miner_name": "Rig #1"
}

Response:
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

#### End Mining Session
```bash
POST /api/miner/sessions/<session_id>/end
Authorization: Bearer <token>
Content-Type: application/json

{
    "blocks_found": 5,
    "rewards_earned": 150.0
}
```

### Rewards

#### Get Rewards History
```bash
GET /api/rewards?limit=50&offset=0
Authorization: Bearer <token>

Response:
{
    "rewards": [...],
    "total": 25,
    "limit": 50,
    "offset": 0
}
```

#### Request Withdrawal
```bash
POST /api/rewards/withdraw
Authorization: Bearer <token>
Content-Type: application/json

{
    "amount": 100.0,
    "wallet_address": "RTC1YourWalletAddress"
}
```

#### Get Withdrawal History
```bash
GET /api/withdrawals
Authorization: Bearer <token>
```

### Leaderboard

#### Get Global Leaderboard
```bash
GET /api/leaderboard?limit=10

Response:
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

### System

#### Health Check
```bash
GET /api/health

Response:
{
    "status": "healthy",
    "database": "healthy",
    "redis": "healthy",
    "timestamp": "2026-03-26T10:32:00Z"
}
```

## 🔧 Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `JWT_SECRET` | Secret key for JWT tokens | (must set) |
| `DATABASE_URL` | PostgreSQL connection string | Auto-configured |
| `REDIS_URL` | Redis connection string | Auto-configured |
| `NGINX_PORT` | Nginx exposed port | 8080 |

### Database Schema

The system uses 5 main tables:
- `users` - Miner accounts
- `mining_sessions` - Active/completed mining sessions
- `rewards` - Reward records
- `withdrawals` - Withdrawal requests
- `pool_stats` - Pool-wide statistics

## 🏗️ Architecture

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   Client    │────▶│    Nginx    │────▶│  Flask API  │
│  (Browser/  │     │  (Port 80)  │     │ (Port 5000) │
│   Mobile)   │     │ Rate Limit  │     │             │
└─────────────┘     └─────────────┘     └──────┬──────┘
                                               │
                    ┌──────────────────────────┼──────────────────────────┐
                    │                          │                          │
                    ▼                          ▼                          ▼
            ┌───────────────┐         ┌───────────────┐         ┌───────────────┐
            │   PostgreSQL  │         │     Redis     │         │   File System │
            │   (Port 5432) │         │   (Port 6379) │         │   (Volumes)   │
            │   16.4-alpine │         │    7.4-alpine │         │               │
            └───────────────┘         └───────────────┘         └───────────────┘
```

## 🛡️ Security Features

- **JWT Authentication** - Secure token-based auth with 30-day expiry
- **Password Hashing** - SHA-256 password hashing
- **Rate Limiting** - 10 requests/second per IP
- **Connection Limits** - Max 10 concurrent connections per IP
- **Security Headers** - X-Frame-Options, X-Content-Type-Options, etc.
- **Non-root User** - Application runs as unprivileged user
- **SQL Injection Protection** - Parameterized queries

## 📊 Monitoring

### Docker Compose Logs
```bash
# View all logs
docker-compose logs -f

# View specific service
docker-compose logs -f api
```

### Health Endpoints
- API Health: `http://localhost:8080/api/health`
- Database: Included in API health check
- Redis: Included in API health check

## 🧪 Testing

### Run Test Suite
```bash
./test-api.sh
```

### Manual Testing
```bash
# Register
curl -X POST http://localhost:8080/api/register \
  -H "Content-Type: application/json" \
  -d '{"username":"test","password":"test123","wallet_address":"RTC1Test","miner_name":"Test"}'

# Login
curl -X POST http://localhost:8080/api/login \
  -H "Content-Type: application/json" \
  -d '{"username":"test","password":"test123"}'
```

## 📝 Development

### Local Development
```bash
# Build and start
docker-compose up --build

# Rebuild specific service
docker-compose up --build api

# Stop all services
docker-compose down

# Stop and remove volumes
docker-compose down -v
```

### Database Access
```bash
# Connect to PostgreSQL
docker exec -it founding-miner-postgres psql -U founding_miner -d founding_miner

# Connect to Redis
docker exec -it founding-miner-redis redis-cli
```

## 📦 Deliverables

| File | Description |
|------|-------------|
| `app/app.py` | Flask API (600+ lines) |
| `docker-compose.yml` | Service orchestration |
| `Dockerfile` | API container image |
| `init-db/001-schema.sql` | Database schema |
| `nginx/nginx.conf` | Nginx configuration |
| `nginx/conf.d/founding-miner.conf` | API proxy config |
| `requirements.txt` | Python dependencies |
| `.env.example` | Environment template |
| `test-api.sh` | API test script |
| `README.md` | Documentation |

## 💰 Reward Claim

**Wallet**: See `.env` or contact project admin  
**Amount**: ~75 RTC  

## 📄 License

MIT License - See project repository for details.

## 🤝 Support

For issues or questions, please open an issue on the project repository.

---

**Developed for RustChain Bounties** 🦀  
**Issue #2451 - Founding Miner**
