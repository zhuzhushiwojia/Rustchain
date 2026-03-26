"""
RustChain Founding Miner - Mining Dashboard & Reward Management
Issue: #2451 (~75 RTC)
"""

from flask import Flask, request, jsonify, g
from flask_cors import CORS
from functools import wraps
import jwt
import datetime
import psycopg2
from psycopg2.extras import RealDictCursor
import redis
import hashlib
import os
import logging
from typing import Optional, Dict, Any

# Configuration
app = Flask(__name__)
CORS(app)

# Environment variables
DATABASE_URL = os.getenv('DATABASE_URL', 'postgresql://miner:miner_password@postgres:5432/founding_miner')
REDIS_URL = os.getenv('REDIS_URL', 'redis://redis:6379/0')
JWT_SECRET = os.getenv('JWT_SECRET', 'founding-miner-secret-key-change-in-production')
JWT_ALGORITHM = 'HS256'
TOKEN_EXPIRY_DAYS = 30

# Logging setup
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# =============================================================================
# Database Connection
# =============================================================================

def get_db():
    """Get database connection for current request"""
    if 'db' not in g:
        g.db = psycopg2.connect(DATABASE_URL)
        g.db.cursor_factory = RealDictCursor
    return g.db

@app.teardown_appcontext
def close_db(error):
    """Close database connection at end of request"""
    db = g.pop('db', None)
    if db is not None:
        db.close()

def get_redis():
    """Get Redis connection"""
    return redis.from_url(REDIS_URL)

# =============================================================================
# Authentication
# =============================================================================

def token_required(f):
    """Decorator to require valid JWT token"""
    @wraps(f)
    def decorated(*args, **kwargs):
        token = None
        if 'Authorization' in request.headers:
            auth_header = request.headers['Authorization']
            if auth_header.startswith('Bearer '):
                token = auth_header.split(' ')[1]
        
        if not token:
            return jsonify({'error': 'Token is missing'}), 401
        
        try:
            data = jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGORITHM])
            current_user = data['user_id']
        except jwt.ExpiredSignatureError:
            return jsonify({'error': 'Token has expired'}), 401
        except jwt.InvalidTokenError:
            return jsonify({'error': 'Invalid token'}), 401
        
        return f(current_user, *args, **kwargs)
    return decorated

def generate_token(user_id: int, username: str) -> str:
    """Generate JWT token for user"""
    payload = {
        'user_id': user_id,
        'username': username,
        'exp': datetime.datetime.utcnow() + datetime.timedelta(days=TOKEN_EXPIRY_DAYS),
        'iat': datetime.datetime.utcnow()
    }
    return jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALGORITHM)

def hash_password(password: str) -> str:
    """Hash password using SHA-256"""
    return hashlib.sha256(password.encode()).hexdigest()

# =============================================================================
# User Routes
# =============================================================================

@app.route('/api/register', methods=['POST'])
def register():
    """Register a new miner"""
    data = request.get_json()
    
    if not data or not data.get('username') or not data.get('password'):
        return jsonify({'error': 'Username and password required'}), 400
    
    username = data['username']
    password = hash_password(data['password'])
    wallet_address = data.get('wallet_address', '')
    miner_name = data.get('miner_name', username)
    
    db = get_db()
    cur = db.cursor()
    
    try:
        # Check if username exists
        cur.execute('SELECT id FROM users WHERE username = %s', (username,))
        if cur.fetchone():
            return jsonify({'error': 'Username already exists'}), 409
        
        # Create user
        cur.execute('''
            INSERT INTO users (username, password_hash, wallet_address, miner_name, created_at)
            VALUES (%s, %s, %s, %s, NOW())
            RETURNING id, username, wallet_address, miner_name, created_at
        ''', (username, password, wallet_address, miner_name))
        
        user = cur.fetchone()
        db.commit()
        
        # Generate token
        token = generate_token(user['id'], user['username'])
        
        logger.info(f"New miner registered: {username}")
        
        return jsonify({
            'message': 'Registration successful',
            'user': {
                'id': user['id'],
                'username': user['username'],
                'wallet_address': user['wallet_address'],
                'miner_name': user['miner_name'],
                'created_at': str(user['created_at'])
            },
            'token': token
        }), 201
    
    except Exception as e:
        db.rollback()
        logger.error(f"Registration error: {str(e)}")
        return jsonify({'error': 'Registration failed'}), 500
    
    finally:
        cur.close()

@app.route('/api/login', methods=['POST'])
def login():
    """Login and get JWT token"""
    data = request.get_json()
    
    if not data or not data.get('username') or not data.get('password'):
        return jsonify({'error': 'Username and password required'}), 400
    
    username = data['username']
    password_hash = hash_password(data['password'])
    
    db = get_db()
    cur = db.cursor()
    
    try:
        cur.execute('''
            SELECT id, username, wallet_address, miner_name, created_at
            FROM users
            WHERE username = %s AND password_hash = %s
        ''', (username, password_hash))
        
        user = cur.fetchone()
        
        if not user:
            return jsonify({'error': 'Invalid credentials'}), 401
        
        token = generate_token(user['id'], user['username'])
        
        # Update last login
        cur.execute('UPDATE users SET last_login = NOW() WHERE id = %s', (user['id'],))
        db.commit()
        
        logger.info(f"Miner logged in: {username}")
        
        return jsonify({
            'message': 'Login successful',
            'user': {
                'id': user['id'],
                'username': user['username'],
                'wallet_address': user['wallet_address'],
                'miner_name': user['miner_name'],
                'created_at': str(user['created_at'])
            },
            'token': token
        })
    
    except Exception as e:
        logger.error(f"Login error: {str(e)}")
        return jsonify({'error': 'Login failed'}), 500
    
    finally:
        cur.close()

# =============================================================================
# Miner Dashboard Routes
# =============================================================================

@app.route('/api/miner/stats', methods=['GET'])
@token_required
def get_miner_stats(current_user):
    """Get miner statistics"""
    db = get_db()
    cur = db.cursor()
    
    try:
        # Get total rewards
        cur.execute('''
            SELECT COALESCE(SUM(amount), 0) as total_rewards,
                   COUNT(*) as reward_count
            FROM rewards
            WHERE user_id = %s
        ''', (current_user,))
        reward_stats = cur.fetchone()
        
        # Get mining sessions
        cur.execute('''
            SELECT COUNT(*) as total_sessions,
                   SUM(EXTRACT(EPOCH FROM (end_time - start_time))) / 3600 as total_hours
            FROM mining_sessions
            WHERE user_id = %s
        ''', (current_user,))
        session_stats = cur.fetchone()
        
        # Get recent activity
        cur.execute('''
            SELECT r.*, ms.miner_name
            FROM rewards r
            JOIN mining_sessions ms ON r.session_id = ms.id
            WHERE r.user_id = %s
            ORDER BY r.created_at DESC
            LIMIT 10
        ''', (current_user,))
        recent_rewards = cur.fetchall()
        
        return jsonify({
            'total_rewards': float(reward_stats['total_rewards']),
            'reward_count': reward_stats['reward_count'],
            'total_sessions': session_stats['total_sessions'],
            'total_mining_hours': float(session_stats['total_hours']) if session_stats['total_hours'] else 0,
            'recent_rewards': [dict(r) for r in recent_rewards]
        })
    
    except Exception as e:
        logger.error(f"Stats error: {str(e)}")
        return jsonify({'error': 'Failed to get stats'}), 500
    
    finally:
        cur.close()

@app.route('/api/miner/sessions', methods=['GET'])
@token_required
def get_mining_sessions(current_user):
    """Get mining sessions for user"""
    db = get_db()
    cur = db.cursor()
    
    try:
        limit = request.args.get('limit', 50, type=int)
        offset = request.args.get('offset', 0, type=int)
        
        cur.execute('''
            SELECT id, miner_name, start_time, end_time,
                   blocks_found, rewards_earned, status
            FROM mining_sessions
            WHERE user_id = %s
            ORDER BY start_time DESC
            LIMIT %s OFFSET %s
        ''', (current_user, limit, offset))
        
        sessions = cur.fetchall()
        
        # Get total count
        cur.execute('SELECT COUNT(*) as count FROM mining_sessions WHERE user_id = %s', (current_user,))
        total = cur.fetchone()['count']
        
        return jsonify({
            'sessions': [dict(s) for s in sessions],
            'total': total,
            'limit': limit,
            'offset': offset
        })
    
    except Exception as e:
        logger.error(f"Sessions error: {str(e)}")
        return jsonify({'error': 'Failed to get sessions'}), 500
    
    finally:
        cur.close()

@app.route('/api/miner/sessions', methods=['POST'])
@token_required
def start_mining_session(current_user):
    """Start a new mining session"""
    data = request.get_json()
    
    if not data or not data.get('miner_name'):
        return jsonify({'error': 'Miner name required'}), 400
    
    db = get_db()
    cur = db.cursor()
    
    try:
        miner_name = data['miner_name']
        
        cur.execute('''
            INSERT INTO mining_sessions (user_id, miner_name, start_time, status)
            VALUES (%s, %s, NOW(), 'active')
            RETURNING id, miner_name, start_time, status
        ''', (current_user, miner_name))
        
        session = cur.fetchone()
        db.commit()
        
        logger.info(f"Mining session started: {miner_name} by user {current_user}")
        
        return jsonify({
            'message': 'Mining session started',
            'session': dict(session)
        }), 201
    
    except Exception as e:
        db.rollback()
        logger.error(f"Start session error: {str(e)}")
        return jsonify({'error': 'Failed to start session'}), 500
    
    finally:
        cur.close()

@app.route('/api/miner/sessions/<int:session_id>/end', methods=['POST'])
@token_required
def end_mining_session(current_user, session_id):
    """End a mining session"""
    data = request.get_json() or {}
    
    db = get_db()
    cur = db.cursor()
    
    try:
        blocks_found = data.get('blocks_found', 0)
        rewards_earned = data.get('rewards_earned', 0)
        
        # Verify session belongs to user
        cur.execute('''
            SELECT id FROM mining_sessions
            WHERE id = %s AND user_id = %s AND status = 'active'
        ''', (session_id, current_user))
        
        if not cur.fetchone():
            return jsonify({'error': 'Session not found or not active'}), 404
        
        cur.execute('''
            UPDATE mining_sessions
            SET end_time = NOW(),
                blocks_found = %s,
                rewards_earned = %s,
                status = 'completed'
            WHERE id = %s AND user_id = %s
            RETURNING id, end_time, blocks_found, rewards_earned
        ''', (blocks_found, rewards_earned, session_id, current_user))
        
        session = cur.fetchone()
        
        # Create reward record if rewards earned
        if rewards_earned > 0:
            cur.execute('''
                INSERT INTO rewards (user_id, session_id, amount, created_at)
                VALUES (%s, %s, %s, NOW())
            ''', (current_user, session_id, rewards_earned))
        
        db.commit()
        
        logger.info(f"Mining session ended: {session_id}, rewards: {rewards_earned}")
        
        return jsonify({
            'message': 'Mining session ended',
            'session': dict(session)
        })
    
    except Exception as e:
        db.rollback()
        logger.error(f"End session error: {str(e)}")
        return jsonify({'error': 'Failed to end session'}), 500
    
    finally:
        cur.close()

# =============================================================================
# Rewards Routes
# =============================================================================

@app.route('/api/rewards', methods=['GET'])
@token_required
def get_rewards(current_user):
    """Get rewards history"""
    db = get_db()
    cur = db.cursor()
    
    try:
        limit = request.args.get('limit', 50, type=int)
        offset = request.args.get('offset', 0, type=int)
        
        cur.execute('''
            SELECT r.id, r.amount, r.created_at,
                   ms.miner_name, ms.start_time, ms.end_time
            FROM rewards r
            LEFT JOIN mining_sessions ms ON r.session_id = ms.id
            WHERE r.user_id = %s
            ORDER BY r.created_at DESC
            LIMIT %s OFFSET %s
        ''', (current_user, limit, offset))
        
        rewards = cur.fetchall()
        
        # Get total count
        cur.execute('SELECT COUNT(*) as count FROM rewards WHERE user_id = %s', (current_user,))
        total = cur.fetchone()['count']
        
        return jsonify({
            'rewards': [dict(r) for r in rewards],
            'total': total,
            'limit': limit,
            'offset': offset
        })
    
    except Exception as e:
        logger.error(f"Rewards error: {str(e)}")
        return jsonify({'error': 'Failed to get rewards'}), 500
    
    finally:
        cur.close()

@app.route('/api/rewards/withdraw', methods=['POST'])
@token_required
def withdraw_rewards(current_user):
    """Request withdrawal of rewards"""
    data = request.get_json()
    
    if not data or not data.get('amount'):
        return jsonify({'error': 'Amount required'}), 400
    
    amount = float(data['amount'])
    wallet_address = data.get('wallet_address')
    
    db = get_db()
    cur = db.cursor()
    
    try:
        # Get user's wallet if not provided
        if not wallet_address:
            cur.execute('SELECT wallet_address FROM users WHERE id = %s', (current_user,))
            user = cur.fetchone()
            if not user or not user['wallet_address']:
                return jsonify({'error': 'Wallet address required'}), 400
            wallet_address = user['wallet_address']
        
        # Get available balance
        cur.execute('''
            SELECT COALESCE(SUM(amount), 0) as total_earned
            FROM rewards
            WHERE user_id = %s
        ''', (current_user,))
        total_earned = float(cur.fetchone()['total_earned'])
        
        cur.execute('''
            SELECT COALESCE(SUM(amount), 0) as total_withdrawn
            FROM withdrawals
            WHERE user_id = %s AND status = 'completed'
        ''', (current_user,))
        total_withdrawn = float(cur.fetchone()['total_withdrawn'])
        
        available = total_earned - total_withdrawn
        
        if amount > available:
            return jsonify({
                'error': 'Insufficient balance',
                'available': available,
                'requested': amount
            }), 400
        
        # Create withdrawal request
        cur.execute('''
            INSERT INTO withdrawals (user_id, amount, wallet_address, status, created_at)
            VALUES (%s, %s, %s, 'pending', NOW())
            RETURNING id, amount, wallet_address, status, created_at
        ''', (current_user, amount, wallet_address))
        
        withdrawal = cur.fetchone()
        db.commit()
        
        logger.info(f"Withdrawal requested: {amount} by user {current_user}")
        
        return jsonify({
            'message': 'Withdrawal request submitted',
            'withdrawal': dict(withdrawal),
            'available_balance': available - amount
        }), 201
    
    except Exception as e:
        db.rollback()
        logger.error(f"Withdrawal error: {str(e)}")
        return jsonify({'error': 'Failed to process withdrawal'}), 500
    
    finally:
        cur.close()

@app.route('/api/withdrawals', methods=['GET'])
@token_required
def get_withdrawals(current_user):
    """Get withdrawal history"""
    db = get_db()
    cur = db.cursor()
    
    try:
        cur.execute('''
            SELECT id, amount, wallet_address, status, tx_hash,
                   created_at, processed_at
            FROM withdrawals
            WHERE user_id = %s
            ORDER BY created_at DESC
            LIMIT 50
        ''', (current_user,))
        
        withdrawals = cur.fetchall()
        
        return jsonify({
            'withdrawals': [dict(w) for w in withdrawals]
        })
    
    except Exception as e:
        logger.error(f"Withdrawals error: {str(e)}")
        return jsonify({'error': 'Failed to get withdrawals'}), 500
    
    finally:
        cur.close()

# =============================================================================
# Leaderboard Routes
# =============================================================================

@app.route('/api/leaderboard', methods=['GET'])
def get_leaderboard():
    """Get global miner leaderboard"""
    db = get_db()
    cur = db.cursor()
    
    try:
        limit = request.args.get('limit', 10, type=int)
        
        cur.execute('''
            SELECT u.id, u.username, u.miner_name,
                   COUNT(DISTINCT ms.id) as total_sessions,
                   COALESCE(SUM(ms.blocks_found), 0) as total_blocks,
                   COALESCE(SUM(r.amount), 0) as total_rewards
            FROM users u
            LEFT JOIN mining_sessions ms ON u.id = ms.user_id
            LEFT JOIN rewards r ON u.id = r.user_id
            GROUP BY u.id, u.username, u.miner_name
            ORDER BY total_rewards DESC
            LIMIT %s
        ''', (limit,))
        
        leaderboard = cur.fetchall()
        
        return jsonify({
            'leaderboard': [dict(l) for l in leaderboard]
        })
    
    except Exception as e:
        logger.error(f"Leaderboard error: {str(e)}")
        return jsonify({'error': 'Failed to get leaderboard'}), 500
    
    finally:
        cur.close()

# =============================================================================
# Health Check
# =============================================================================

@app.route('/api/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    try:
        # Check database
        db = get_db()
        cur = db.cursor()
        cur.execute('SELECT 1')
        cur.close()
        db_status = 'healthy'
    except Exception as e:
        db_status = f'unhealthy: {str(e)}'
    
    try:
        # Check Redis
        r = get_redis()
        r.ping()
        redis_status = 'healthy'
    except Exception as e:
        redis_status = f'unhealthy: {str(e)}'
    
    overall = 'healthy' if db_status == 'healthy' and redis_status == 'healthy' else 'unhealthy'
    
    return jsonify({
        'status': overall,
        'database': db_status,
        'redis': redis_status,
        'timestamp': datetime.datetime.utcnow().isoformat()
    })

# =============================================================================
# Main
# =============================================================================

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=False)
