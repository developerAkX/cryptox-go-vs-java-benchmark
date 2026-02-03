package repository

import (
	"context"
	"sync"

	"github.com/cryptox/go-exchange/internal/model"
	"github.com/google/uuid"
)

func (db *DB) CreateOrder(ctx context.Context, req model.CreateOrderRequest) (*model.Order, error) {
	order := &model.Order{
		ID:       uuid.New(),
		UserID:   req.UserID,
		Pair:     req.Pair,
		Side:     req.Side,
		Price:    req.Price,
		Quantity: req.Quantity,
		Status:   model.Open,
	}

	query := `
		INSERT INTO orders (id, user_id, pair, side, price, quantity, status, created_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, NOW())
		RETURNING created_at`

	err := db.Pool.QueryRow(ctx, query,
		order.ID, order.UserID, order.Pair, order.Side,
		order.Price, order.Quantity, order.Status,
	).Scan(&order.CreatedAt)

	if err != nil {
		return nil, err
	}

	return order, nil
}

// fetchBids fetches aggregated bid orders (parallel helper)
func (db *DB) fetchBids(ctx context.Context, pair string) ([]model.OrderBookEntry, error) {
	query := `
		SELECT price, SUM(quantity) as total_qty
		FROM orders
		WHERE pair = $1 AND side = 'BUY' AND status = 'OPEN'
		GROUP BY price
		ORDER BY price DESC
		LIMIT 50`

	rows, err := db.Pool.Query(ctx, query, pair)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	bids := make([]model.OrderBookEntry, 0, 50)
	for rows.Next() {
		var entry model.OrderBookEntry
		if err := rows.Scan(&entry.Price, &entry.Quantity); err != nil {
			return nil, err
		}
		bids = append(bids, entry)
	}

	return bids, nil
}

// fetchAsks fetches aggregated ask orders (parallel helper)
func (db *DB) fetchAsks(ctx context.Context, pair string) ([]model.OrderBookEntry, error) {
	query := `
		SELECT price, SUM(quantity) as total_qty
		FROM orders
		WHERE pair = $1 AND side = 'SELL' AND status = 'OPEN'
		GROUP BY price
		ORDER BY price ASC
		LIMIT 50`

	rows, err := db.Pool.Query(ctx, query, pair)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	asks := make([]model.OrderBookEntry, 0, 50)
	for rows.Next() {
		var entry model.OrderBookEntry
		if err := rows.Scan(&entry.Price, &entry.Quantity); err != nil {
			return nil, err
		}
		asks = append(asks, entry)
	}

	return asks, nil
}

// GetOrderBook fetches order book with parallel queries for bids and asks
func (db *DB) GetOrderBook(ctx context.Context, pair string) (*model.OrderBookResponse, error) {
	var wg sync.WaitGroup
	var bidsErr, asksErr error
	var bids, asks []model.OrderBookEntry

	wg.Add(2)

	// Fetch bids concurrently
	go func() {
		defer wg.Done()
		bids, bidsErr = db.fetchBids(ctx, pair)
	}()

	// Fetch asks concurrently
	go func() {
		defer wg.Done()
		asks, asksErr = db.fetchAsks(ctx, pair)
	}()

	wg.Wait()

	if bidsErr != nil {
		return nil, bidsErr
	}
	if asksErr != nil {
		return nil, asksErr
	}

	return &model.OrderBookResponse{
		Pair: pair,
		Bids: bids,
		Asks: asks,
	}, nil
}

func (db *DB) GetUserBalances(ctx context.Context, userID uuid.UUID) (*model.BalanceResponse, error) {
	response := &model.BalanceResponse{
		UserID:   userID,
		Balances: make(map[string]float64),
	}

	query := `SELECT currency, balance FROM wallets WHERE user_id = $1`
	rows, err := db.Pool.Query(ctx, query, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	for rows.Next() {
		var currency string
		var balance float64
		if err := rows.Scan(&currency, &balance); err != nil {
			return nil, err
		}
		response.Balances[currency] = balance
	}

	return response, nil
}

func (db *DB) MatchOrders(ctx context.Context, pair string) (*model.MatchResult, error) {
	result := &model.MatchResult{}

	// Start transaction
	tx, err := db.Pool.Begin(ctx)
	if err != nil {
		return nil, err
	}
	defer tx.Rollback(ctx)

	// Find matching orders: best bid >= best ask
	matchQuery := `
		WITH best_bid AS (
			SELECT id, user_id, price, quantity
			FROM orders
			WHERE pair = $1 AND side = 'BUY' AND status = 'OPEN'
			ORDER BY price DESC, created_at ASC
			LIMIT 1
			FOR UPDATE SKIP LOCKED
		),
		best_ask AS (
			SELECT id, user_id, price, quantity
			FROM orders
			WHERE pair = $1 AND side = 'SELL' AND status = 'OPEN'
			ORDER BY price ASC, created_at ASC
			LIMIT 1
			FOR UPDATE SKIP LOCKED
		)
		SELECT 
			b.id as bid_id, b.price as bid_price, b.quantity as bid_qty,
			a.id as ask_id, a.price as ask_price, a.quantity as ask_qty
		FROM best_bid b, best_ask a
		WHERE b.price >= a.price`

	var bidID, askID uuid.UUID
	var bidPrice, bidQty, askPrice, askQty float64

	err = tx.QueryRow(ctx, matchQuery, pair).Scan(
		&bidID, &bidPrice, &bidQty,
		&askID, &askPrice, &askQty,
	)

	if err != nil {
		// No match found - this is normal
		return result, nil
	}

	// Calculate trade quantity (minimum of both)
	tradeQty := bidQty
	if askQty < tradeQty {
		tradeQty = askQty
	}
	tradePrice := askPrice // Execute at ask price

	// Create trade record
	tradeID := uuid.New()
	_, err = tx.Exec(ctx, `
		INSERT INTO trades (id, buy_order_id, sell_order_id, price, quantity, executed_at)
		VALUES ($1, $2, $3, $4, $5, NOW())`,
		tradeID, bidID, askID, tradePrice, tradeQty)
	if err != nil {
		return nil, err
	}

	// Update order statuses
	if bidQty == tradeQty {
		_, err = tx.Exec(ctx, `UPDATE orders SET status = 'FILLED' WHERE id = $1`, bidID)
	} else {
		_, err = tx.Exec(ctx, `UPDATE orders SET quantity = quantity - $1 WHERE id = $2`, tradeQty, bidID)
	}
	if err != nil {
		return nil, err
	}

	if askQty == tradeQty {
		_, err = tx.Exec(ctx, `UPDATE orders SET status = 'FILLED' WHERE id = $1`, askID)
	} else {
		_, err = tx.Exec(ctx, `UPDATE orders SET quantity = quantity - $1 WHERE id = $2`, tradeQty, askID)
	}
	if err != nil {
		return nil, err
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, err
	}

	result.TradesExecuted = 1
	result.VolumeMatched = tradeQty * tradePrice

	return result, nil
}
