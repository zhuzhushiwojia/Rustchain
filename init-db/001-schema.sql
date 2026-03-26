-- RustChain Founding Miner Database Schema
-- Issue: #2451 (~75 RTC)

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Users table (miners)
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(64) NOT NULL,
    wallet_address VARCHAR(255),
    miner_name VARCHAR(255),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    last_login TIMESTAMP WITH TIME ZONE,
    is_active BOOLEAN DEFAULT TRUE
);

-- Mining sessions table
CREATE TABLE IF NOT EXISTS mining_sessions (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    miner_name VARCHAR(255) NOT NULL,
    start_time TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    end_time TIMESTAMP WITH TIME ZONE,
    blocks_found INTEGER DEFAULT 0,
    rewards_earned DECIMAL(18, 8) DEFAULT 0,
    status VARCHAR(50) DEFAULT 'active' CHECK (status IN ('active', 'completed', 'failed')),
    metadata JSONB DEFAULT '{}'::jsonb
);

-- Rewards table
CREATE TABLE IF NOT EXISTS rewards (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    session_id INTEGER REFERENCES mining_sessions(id) ON DELETE SET NULL,
    amount DECIMAL(18, 8) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    notes TEXT
);

-- Withdrawals table
CREATE TABLE IF NOT EXISTS withdrawals (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    amount DECIMAL(18, 8) NOT NULL,
    wallet_address VARCHAR(255) NOT NULL,
    status VARCHAR(50) DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'completed', 'failed', 'cancelled')),
    tx_hash VARCHAR(255),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    processed_at TIMESTAMP WITH TIME ZONE,
    notes TEXT
);

-- Mining pool stats (for admin/dashboard)
CREATE TABLE IF NOT EXISTS pool_stats (
    id SERIAL PRIMARY KEY,
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    total_miners INTEGER DEFAULT 0,
    active_sessions INTEGER DEFAULT 0,
    total_hashrate DECIMAL(18, 2) DEFAULT 0,
    blocks_found_24h INTEGER DEFAULT 0,
    rewards_distributed_24h DECIMAL(18, 8) DEFAULT 0
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_users_username ON users(username);
CREATE INDEX IF NOT EXISTS idx_mining_sessions_user_id ON mining_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_mining_sessions_status ON mining_sessions(status);
CREATE INDEX IF NOT EXISTS idx_mining_sessions_start_time ON mining_sessions(start_time);
CREATE INDEX IF NOT EXISTS idx_rewards_user_id ON rewards(user_id);
CREATE INDEX IF NOT EXISTS idx_rewards_created_at ON rewards(created_at);
CREATE INDEX IF NOT EXISTS idx_withdrawals_user_id ON withdrawals(user_id);
CREATE INDEX IF NOT EXISTS idx_withdrawals_status ON withdrawals(status);
CREATE INDEX IF NOT EXISTS idx_pool_stats_timestamp ON pool_stats(timestamp);

-- Insert sample data for testing
INSERT INTO users (username, password_hash, wallet_address, miner_name) VALUES
    ('founding_miner_1', SHA256('password123'), 'RTC1FoundingMiner1WalletAddress123456', 'Founding Miner Alpha'),
    ('founding_miner_2', SHA256('password123'), 'RTC1FoundingMiner2WalletAddress123456', 'Founding Miner Beta'),
    ('founding_miner_3', SHA256('password123'), 'RTC1FoundingMiner3WalletAddress123456', 'Founding Miner Gamma');

-- Insert sample mining sessions
INSERT INTO mining_sessions (user_id, miner_name, start_time, end_time, blocks_found, rewards_earned, status) VALUES
    (1, 'Founding Miner Alpha', NOW() - INTERVAL '7 days', NOW() - INTERVAL '6 days', 5, 150.0, 'completed'),
    (1, 'Founding Miner Alpha', NOW() - INTERVAL '5 days', NOW() - INTERVAL '4 days', 3, 90.0, 'completed'),
    (2, 'Founding Miner Beta', NOW() - INTERVAL '3 days', NOW() - INTERVAL '2 days', 8, 240.0, 'completed'),
    (3, 'Founding Miner Gamma', NOW() - INTERVAL '1 day', NULL, 2, 0, 'active');

-- Insert sample rewards
INSERT INTO rewards (user_id, session_id, amount, notes) VALUES
    (1, 1, 150.0, 'Block rewards from session 1'),
    (1, 2, 90.0, 'Block rewards from session 2'),
    (2, 3, 240.0, 'Block rewards from session 3');

-- Insert sample pool stats
INSERT INTO pool_stats (total_miners, active_sessions, total_hashrate, blocks_found_24h, rewards_distributed_24h) VALUES
    (3, 1, 1500.50, 12, 360.0);
