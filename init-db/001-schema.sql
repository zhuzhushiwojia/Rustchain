-- Rent-a-Relic Market Database Schema
-- RustChain Bounty #2312

-- Users table
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(64) NOT NULL,
    role VARCHAR(20) DEFAULT 'user' CHECK (role IN ('user', 'admin', 'moderator')),
    avatar_url TEXT,
    bio TEXT,
    rating DECIMAL(3,2) DEFAULT 5.00,
    total_rentals INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- API tokens for authentication
CREATE TABLE IF NOT EXISTS api_tokens (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    token_hash VARCHAR(64) UNIQUE NOT NULL,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Relics (rental items) table
CREATE TABLE IF NOT EXISTS relics (
    id SERIAL PRIMARY KEY,
    owner_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    description TEXT NOT NULL,
    category VARCHAR(50) NOT NULL,
    daily_rate DECIMAL(10,2) NOT NULL,
    deposit_amount DECIMAL(10,2) NOT NULL,
    condition VARCHAR(20) DEFAULT 'good' CHECK (condition IN ('excellent', 'good', 'fair', 'poor')),
    images TEXT[], -- Array of image URLs
    availability_start DATE,
    availability_end DATE,
    status VARCHAR(20) DEFAULT 'available' CHECK (status IN ('available', 'rented', 'maintenance', 'retired')),
    location VARCHAR(255),
    shipping_available BOOLEAN DEFAULT false,
    rating DECIMAL(3,2) DEFAULT 5.00,
    total_rentals INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Rentals table
CREATE TABLE IF NOT EXISTS rentals (
    id SERIAL PRIMARY KEY,
    relic_id INTEGER REFERENCES relics(id) ON DELETE CASCADE,
    renter_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    owner_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    total_cost DECIMAL(10,2) NOT NULL,
    deposit_amount DECIMAL(10,2) NOT NULL,
    deposit_returned BOOLEAN DEFAULT false,
    status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'confirmed', 'active', 'completed', 'cancelled', 'disputed')),
    payment_status VARCHAR(20) DEFAULT 'pending' CHECK (payment_status IN ('pending', 'paid', 'refunded', 'partial')),
    shipping_address TEXT,
    return_tracking VARCHAR(255),
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Reviews table
CREATE TABLE IF NOT EXISTS reviews (
    id SERIAL PRIMARY KEY,
    rental_id INTEGER REFERENCES rentals(id) ON DELETE CASCADE,
    reviewer_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    reviewee_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
    comment TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Categories table (for standardized categories)
CREATE TABLE IF NOT EXISTS categories (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50) UNIQUE NOT NULL,
    description TEXT,
    parent_id INTEGER REFERENCES categories(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_relics_owner ON relics(owner_id);
CREATE INDEX IF NOT EXISTS idx_relics_category ON relics(category);
CREATE INDEX IF NOT EXISTS idx_relics_status ON relics(status);
CREATE INDEX IF NOT EXISTS idx_rentals_relic ON rentals(relic_id);
CREATE INDEX IF NOT EXISTS idx_rentals_renter ON rentals(renter_id);
CREATE INDEX IF NOT EXISTS idx_rentals_owner ON rentals(owner_id);
CREATE INDEX IF NOT EXISTS idx_rentals_status ON rentals(status);
CREATE INDEX IF NOT EXISTS idx_users_username ON users(username);
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);

-- Insert default categories
INSERT INTO categories (name, description) VALUES
    ('Ancient Artifacts', 'Items from ancient civilizations'),
    ('Medieval Relics', 'Artifacts from the medieval period'),
    ('Victorian Era', 'Items from the Victorian period'),
    ('Art Deco', 'Decorative arts from 1920s-1930s'),
    ('Vintage Technology', 'Historic technological devices'),
    ('Collectible Books', 'Rare and antique books'),
    ('Fine Art', 'Paintings, sculptures, and other art pieces'),
    ('Jewelry & Watches', 'Vintage and antique jewelry'),
    ('Furniture', 'Antique and vintage furniture'),
    ('Musical Instruments', 'Historic musical instruments')
ON CONFLICT (name) DO NOTHING;

-- Insert sample data for testing
INSERT INTO users (username, email, password_hash, role, bio) VALUES
    ('relic_master', 'admin@rustchain.io', sha256('admin123'::text), 'admin', 'Official RustChain admin account'),
    ('ancient_collector', 'collector@example.com', sha256('password123'::text), 'user', 'Passionate about ancient artifacts'),
    ('vintage_lover', 'vintage@example.com', sha256('password123'::text), 'user', 'Victorian era enthusiast')
ON CONFLICT (username) DO NOTHING;

INSERT INTO relics (owner_id, name, description, category, daily_rate, deposit_amount, condition, status, location) VALUES
    (1, 'Roman Bronze Coin Collection', 'Authentic Roman bronze coins from 100-300 AD. Set of 10 coins in excellent condition.', 'Ancient Artifacts', 50.00, 500.00, 'excellent', 'available', 'Beijing, China'),
    (1, 'Medieval Sword Replica', 'High-quality replica of a 14th century knight sword. Museum-grade craftsmanship.', 'Medieval Relics', 75.00, 800.00, 'excellent', 'available', 'Shanghai, China'),
    (1, 'Victorian Pocket Watch', 'Original 1880s Swiss pocket watch with gold casing. Fully functional.', 'Victorian Era', 100.00, 1000.00, 'good', 'available', 'Guangzhou, China'),
    (1, '1920s Art Deco Lamp', 'Beautiful bronze Art Deco table lamp with original shade.', 'Art Deco', 40.00, 400.00, 'good', 'available', 'Shenzhen, China'),
    (1, 'Vintage Typewriter', '1940s Royal Quiet De Luxe portable typewriter. Fully restored and working.', 'Vintage Technology', 35.00, 350.00, 'excellent', 'available', 'Hangzhou, China');
