"""
Rent-a-Relic Market - RustChain Bounty #2312
租赁市场平台 - 古老/稀有物品租赁服务
"""

import os
import json
import hashlib
import secrets
from datetime import datetime, timedelta
from functools import wraps

from flask import Flask, request, jsonify, g
from flask_cors import CORS
import psycopg2
from psycopg2.extras import RealDictCursor
import redis

app = Flask(__name__)
app.config['SECRET_KEY'] = os.environ.get('SECRET_KEY', secrets.token_hex(32))
CORS(app)

# Database connection
def get_db():
    if 'db' not in g:
        g.db = psycopg2.connect(
            host='postgres',
            database='rustchain_market',
            user='rustchain',
            password=os.environ.get('POSTGRES_PASSWORD', 'rustchain_password'),
            cursor_factory=RealDictCursor
        )
    return g.db

@app.teardown_appcontext
def close_db(exception):
    db = g.pop('db', None)
    if db is not None:
        db.close()

# Redis cache
def get_redis():
    if 'redis' not in g:
        g.redis = redis.from_url(os.environ.get('REDIS_URL', 'redis://redis:6379/0'))
    return g.redis

# Authentication decorator
def require_auth(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        auth_header = request.headers.get('Authorization')
        if not auth_header or not auth_header.startswith('Bearer '):
            return jsonify({'error': 'Missing or invalid authorization header'}), 401
        
        token = auth_header[7:]
        token_hash = hashlib.sha256(token.encode()).hexdigest()
        
        db = get_db()
        cur = db.cursor()
        cur.execute("""
            SELECT u.id, u.username, u.email, u.role
            FROM users u
            JOIN api_tokens t ON u.id = t.user_id
            WHERE t.token_hash = %s AND t.expires_at > NOW()
        """, (token_hash,))
        user = cur.fetchone()
        cur.close()
        
        if not user:
            return jsonify({'error': 'Invalid or expired token'}), 401
        
        g.current_user = dict(user)
        return f(*args, **kwargs)
    return decorated

# Health check endpoint
@app.route('/health', methods=['GET'])
def health_check():
    try:
        # Check database connection
        db = get_db()
        cur = db.cursor()
        cur.execute('SELECT 1')
        cur.close()
        
        # Check Redis connection
        r = get_redis()
        r.ping()
        
        return jsonify({
            'status': 'healthy',
            'timestamp': datetime.utcnow().isoformat(),
            'services': {
                'database': 'connected',
                'redis': 'connected'
            }
        }), 200
    except Exception as e:
        return jsonify({
            'status': 'unhealthy',
            'error': str(e)
        }), 500

# User registration
@app.route('/api/auth/register', methods=['POST'])
def register():
    data = request.get_json()
    
    if not data or not all(k in data for k in ['username', 'email', 'password']):
        return jsonify({'error': 'Missing required fields'}), 400
    
    username = data['username']
    email = data['email']
    password = data['password']
    
    # Hash password
    password_hash = hashlib.sha256(password.encode()).hexdigest()
    
    db = get_db()
    cur = db.cursor()
    
    try:
        cur.execute("""
            INSERT INTO users (username, email, password_hash, role)
            VALUES (%s, %s, %s, 'user')
            RETURNING id, username, email, created_at
        """, (username, email, password_hash))
        
        user = cur.fetchone()
        db.commit()
        
        return jsonify({
            'message': 'User registered successfully',
            'user': {
                'id': user['id'],
                'username': user['username'],
                'email': user['email']
            }
        }), 201
    except psycopg2.IntegrityError:
        db.rollback()
        return jsonify({'error': 'Username or email already exists'}), 409
    finally:
        cur.close()

# User login
@app.route('/api/auth/login', methods=['POST'])
def login():
    data = request.get_json()
    
    if not data or not all(k in data for k in ['username', 'password']):
        return jsonify({'error': 'Missing required fields'}), 400
    
    username = data['username']
    password = data['password']
    password_hash = hashlib.sha256(password.encode()).hexdigest()
    
    db = get_db()
    cur = db.cursor()
    
    cur.execute("""
        SELECT id, username, email, role
        FROM users
        WHERE username = %s AND password_hash = %s
    """, (username, password_hash))
    
    user = cur.fetchone()
    
    if not user:
        cur.close()
        return jsonify({'error': 'Invalid credentials'}), 401
    
    # Generate token
    token = secrets.token_urlsafe(32)
    token_hash = hashlib.sha256(token.encode()).hexdigest()
    expires_at = datetime.utcnow() + timedelta(days=30)
    
    cur.execute("""
        INSERT INTO api_tokens (user_id, token_hash, expires_at)
        VALUES (%s, %s, %s)
    """, (user['id'], token_hash, expires_at))
    
    db.commit()
    cur.close()
    
    return jsonify({
        'message': 'Login successful',
        'token': token,
        'expires_at': expires_at.isoformat(),
        'user': dict(user)
    }), 200

# List all relics (rental items)
@app.route('/api/relics', methods=['GET'])
def list_relics():
    page = request.args.get('page', 1, type=int)
    per_page = request.args.get('per_page', 20, type=int)
    category = request.args.get('category')
    status = request.args.get('status')
    
    offset = (page - 1) * per_page
    
    db = get_db()
    cur = db.cursor()
    
    query = "SELECT * FROM relics WHERE 1=1"
    params = []
    
    if category:
        query += " AND category = %s"
        params.append(category)
    
    if status:
        query += " AND status = %s"
        params.append(status)
    
    query += " ORDER BY created_at DESC LIMIT %s OFFSET %s"
    params.extend([per_page, offset])
    
    cur.execute(query, params)
    relics = cur.fetchall()
    
    # Get total count
    count_query = "SELECT COUNT(*) FROM relics WHERE 1=1"
    count_params = []
    if category:
        count_query += " AND category = %s"
        count_params.append(category)
    if status:
        count_query += " AND status = %s"
        count_params.append(status)
    
    cur.execute(count_query, count_params)
    total = cur.fetchone()['count']
    
    cur.close()
    
    return jsonify({
        'relics': [dict(r) for r in relics],
        'pagination': {
            'page': page,
            'per_page': per_page,
            'total': total,
            'pages': (total + per_page - 1) // per_page
        }
    }), 200

# Get single relic
@app.route('/api/relics/<int:relic_id>', methods=['GET'])
def get_relic(relic_id):
    db = get_db()
    cur = db.cursor()
    
    cur.execute("SELECT * FROM relics WHERE id = %s", (relic_id,))
    relic = cur.fetchone()
    cur.close()
    
    if not relic:
        return jsonify({'error': 'Relic not found'}), 404
    
    return jsonify(dict(relic)), 200

# Create new relic (requires authentication)
@app.route('/api/relics', methods=['POST'])
@require_auth
def create_relic():
    data = request.get_json()
    
    required_fields = ['name', 'description', 'category', 'daily_rate', 'deposit_amount']
    if not all(k in data for k in required_fields):
        return jsonify({'error': 'Missing required fields'}), 400
    
    db = get_db()
    cur = db.cursor()
    
    cur.execute("""
        INSERT INTO relics (
            owner_id, name, description, category,
            daily_rate, deposit_amount, condition,
            availability_start, availability_end, status
        ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, 'available')
        RETURNING *
    """, (
        g.current_user['id'],
        data['name'],
        data['description'],
        data['category'],
        data['daily_rate'],
        data['deposit_amount'],
        data.get('condition', 'good'),
        data.get('availability_start'),
        data.get('availability_end')
    ))
    
    relic = cur.fetchone()
    db.commit()
    cur.close()
    
    return jsonify({
        'message': 'Relic created successfully',
        'relic': dict(relic)
    }), 201

# Rent a relic (requires authentication)
@app.route('/api/relics/<int:relic_id>/rent', methods=['POST'])
@require_auth
def rent_relic(relic_id):
    data = request.get_json()
    
    if not all(k in data for k in ['start_date', 'end_date']):
        return jsonify({'error': 'Missing required fields'}), 400
    
    db = get_db()
    cur = db.cursor()
    
    try:
        # Check relic availability
        cur.execute("""
            SELECT * FROM relics WHERE id = %s AND status = 'available'
        """, (relic_id,))
        relic = cur.fetchone()
        
        if not relic:
            cur.close()
            return jsonify({'error': 'Relic not found or not available'}), 404
        
        # Check for overlapping rentals
        cur.execute("""
            SELECT * FROM rentals
            WHERE relic_id = %s
            AND status IN ('active', 'confirmed')
            AND (
                (start_date <= %s AND end_date >= %s)
                OR (start_date <= %s AND end_date >= %s)
            )
        """, (relic_id, data['start_date'], data['start_date'], data['end_date'], data['end_date']))
        
        if cur.fetchone():
            cur.close()
            return jsonify({'error': 'Relic not available for selected dates'}), 409
        
        # Calculate total cost
        start = datetime.fromisoformat(data['start_date'])
        end = datetime.fromisoformat(data['end_date'])
        days = (end - start).days + 1
        total_cost = float(relic['daily_rate']) * days
        total_deposit = float(relic['deposit_amount'])
        
        # Create rental record
        cur.execute("""
            INSERT INTO rentals (
                relic_id, renter_id, owner_id,
                start_date, end_date, total_cost, deposit_amount,
                status
            ) VALUES (%s, %s, %s, %s, %s, %s, %s, 'pending')
            RETURNING *
        """, (
            relic_id,
            g.current_user['id'],
            relic['owner_id'],
            data['start_date'],
            data['end_date'],
            total_cost,
            total_deposit
        ))
        
        rental = cur.fetchone()
        db.commit()
        
        return jsonify({
            'message': 'Rental request created successfully',
            'rental': dict(rental),
            'cost_breakdown': {
                'daily_rate': relic['daily_rate'],
                'days': days,
                'total_cost': total_cost,
                'deposit': total_deposit,
                'grand_total': total_cost + total_deposit
            }
        }), 201
        
    except Exception as e:
        db.rollback()
        cur.close()
        return jsonify({'error': str(e)}), 500

# Get user's rentals
@app.route('/api/rentals', methods=['GET'])
@require_auth
def get_rentals():
    rental_type = request.args.get('type', 'all')  # all, renting, owning
    
    db = get_db()
    cur = db.cursor()
    
    if rental_type == 'renting':
        cur.execute("""
            SELECT r.*, rel.name as relic_name, rel.category
            FROM rentals r
            JOIN relics rel ON r.relic_id = rel.id
            WHERE r.renter_id = %s
            ORDER BY r.created_at DESC
        """, (g.current_user['id'],))
    elif rental_type == 'owning':
        cur.execute("""
            SELECT r.*, rel.name as relic_name, rel.category,
                   u.username as renter_username
            FROM rentals r
            JOIN relics rel ON r.relic_id = rel.id
            JOIN users u ON r.renter_id = u.id
            WHERE r.owner_id = %s
            ORDER BY r.created_at DESC
        """, (g.current_user['id'],))
    else:
        cur.execute("""
            SELECT r.*, rel.name as relic_name, rel.category
            FROM rentals r
            JOIN relics rel ON r.relic_id = rel.id
            WHERE r.renter_id = %s OR r.owner_id = %s
            ORDER BY r.created_at DESC
        """, (g.current_user['id'], g.current_user['id']))
    
    rentals = cur.fetchall()
    cur.close()
    
    return jsonify({
        'rentals': [dict(r) for r in rentals]
    }), 200

# Update rental status
@app.route('/api/rentals/<int:rental_id>/status', methods=['PUT'])
@require_auth
def update_rental_status(rental_id):
    data = request.get_json()
    
    if 'status' not in data:
        return jsonify({'error': 'Missing status field'}), 400
    
    valid_statuses = ['pending', 'confirmed', 'active', 'completed', 'cancelled', 'disputed']
    if data['status'] not in valid_statuses:
        return jsonify({'error': f'Invalid status. Must be one of: {valid_statuses}'}), 400
    
    db = get_db()
    cur = db.cursor()
    
    # Check ownership
    cur.execute("""
        SELECT * FROM rentals WHERE id = %s AND (owner_id = %s OR renter_id = %s)
    """, (rental_id, g.current_user['id'], g.current_user['id']))
    
    rental = cur.fetchone()
    if not rental:
        cur.close()
        return jsonify({'error': 'Rental not found or access denied'}), 404
    
    cur.execute("""
        UPDATE rentals SET status = %s, updated_at = NOW()
        WHERE id = %s
        RETURNING *
    """, (data['status'], rental_id))
    
    updated_rental = cur.fetchone()
    db.commit()
    cur.close()
    
    return jsonify({
        'message': 'Rental status updated',
        'rental': dict(updated_rental)
    }), 200

# Get user profile
@app.route('/api/users/me', methods=['GET'])
@require_auth
def get_profile():
    return jsonify({
        'user': g.current_user
    }), 200

# Statistics endpoint
@app.route('/api/stats', methods=['GET'])
def get_stats():
    db = get_db()
    cur = db.cursor()
    
    # Total relics
    cur.execute("SELECT COUNT(*) FROM relics")
    total_relics = cur.fetchone()['count']
    
    # Available relics
    cur.execute("SELECT COUNT(*) FROM relics WHERE status = 'available'")
    available_relics = cur.fetchone()['count']
    
    # Active rentals
    cur.execute("SELECT COUNT(*) FROM rentals WHERE status = 'active'")
    active_rentals = cur.fetchone()['count']
    
    # Total users
    cur.execute("SELECT COUNT(*) FROM users")
    total_users = cur.fetchone()['count']
    
    cur.close()
    
    return jsonify({
        'total_relics': total_relics,
        'available_relics': available_relics,
        'active_rentals': active_rentals,
        'total_users': total_users
    }), 200

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=False)
