-- CryptoX Database Schema
-- Shared by both Go and Java exchanges

-- Users table
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) NOT NULL UNIQUE,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Wallets table
CREATE TABLE IF NOT EXISTS wallets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id),
    currency VARCHAR(20) NOT NULL,
    balance DECIMAL(20, 8) NOT NULL DEFAULT 0,
    UNIQUE(user_id, currency)
);

-- Orders table
CREATE TABLE IF NOT EXISTS orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id),
    pair VARCHAR(20) NOT NULL,
    side VARCHAR(4) NOT NULL CHECK (side IN ('BUY', 'SELL')),
    price DECIMAL(20, 8) NOT NULL,
    quantity DECIMAL(20, 8) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'OPEN' CHECK (status IN ('OPEN', 'FILLED', 'CANCELLED')),
    created_at TIMESTAMP DEFAULT NOW()
);

-- Trades table
CREATE TABLE IF NOT EXISTS trades (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    buy_order_id UUID NOT NULL REFERENCES orders(id),
    sell_order_id UUID NOT NULL REFERENCES orders(id),
    price DECIMAL(20, 8) NOT NULL,
    quantity DECIMAL(20, 8) NOT NULL,
    executed_at TIMESTAMP DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_orders_pair_side_status ON orders(pair, side, status);
CREATE INDEX IF NOT EXISTS idx_orders_price_created ON orders(price, created_at);
CREATE INDEX IF NOT EXISTS idx_wallets_user_id ON wallets(user_id);
CREATE INDEX IF NOT EXISTS idx_trades_executed_at ON trades(executed_at);

-- Optimized composite indexes for 10K+ RPS
-- Orderbook aggregation query optimization
CREATE INDEX IF NOT EXISTS idx_orders_orderbook 
ON orders(pair, side, status, price);

-- Partial indexes for order matching (much faster than full table scans)
CREATE INDEX IF NOT EXISTS idx_orders_buy_open 
ON orders(pair, price DESC, created_at ASC) 
WHERE side = 'BUY' AND status = 'OPEN';

CREATE INDEX IF NOT EXISTS idx_orders_sell_open 
ON orders(pair, price ASC, created_at ASC) 
WHERE side = 'SELL' AND status = 'OPEN';

-- Seed data: Create test users
INSERT INTO users (id, email) VALUES 
    ('11111111-1111-1111-1111-111111111111', 'alice@test.com'),
    ('22222222-2222-2222-2222-222222222222', 'bob@test.com'),
    ('33333333-3333-3333-3333-333333333333', 'charlie@test.com')
ON CONFLICT (email) DO NOTHING;

-- Seed data: Create wallets for test users
INSERT INTO wallets (user_id, currency, balance) VALUES
    ('11111111-1111-1111-1111-111111111111', 'BTC', 10.0),
    ('11111111-1111-1111-1111-111111111111', 'USDT', 100000.0),
    ('22222222-2222-2222-2222-222222222222', 'BTC', 5.0),
    ('22222222-2222-2222-2222-222222222222', 'USDT', 50000.0),
    ('33333333-3333-3333-3333-333333333333', 'BTC', 2.0),
    ('33333333-3333-3333-3333-333333333333', 'USDT', 25000.0)
ON CONFLICT (user_id, currency) DO NOTHING;

-- Seed data: Create some initial orders for the order book
INSERT INTO orders (user_id, pair, side, price, quantity, status) VALUES
    -- Buy orders (bids)
    ('11111111-1111-1111-1111-111111111111', 'BTC/USDT', 'BUY', 42000.00, 0.5, 'OPEN'),
    ('22222222-2222-2222-2222-222222222222', 'BTC/USDT', 'BUY', 41900.00, 1.0, 'OPEN'),
    ('33333333-3333-3333-3333-333333333333', 'BTC/USDT', 'BUY', 41800.00, 0.25, 'OPEN'),
    -- Sell orders (asks)
    ('11111111-1111-1111-1111-111111111111', 'BTC/USDT', 'SELL', 42500.00, 0.3, 'OPEN'),
    ('22222222-2222-2222-2222-222222222222', 'BTC/USDT', 'SELL', 42600.00, 0.75, 'OPEN'),
    ('33333333-3333-3333-3333-333333333333', 'BTC/USDT', 'SELL', 42700.00, 1.5, 'OPEN');
