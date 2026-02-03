package model

import (
	"time"

	"github.com/google/uuid"
)

type OrderSide string

const (
	Buy  OrderSide = "BUY"
	Sell OrderSide = "SELL"
)

type OrderStatus string

const (
	Open      OrderStatus = "OPEN"
	Filled    OrderStatus = "FILLED"
	Cancelled OrderStatus = "CANCELLED"
)

type User struct {
	ID        uuid.UUID `json:"id"`
	Email     string    `json:"email"`
	CreatedAt time.Time `json:"created_at"`
}

type Wallet struct {
	ID       uuid.UUID `json:"id"`
	UserID   uuid.UUID `json:"user_id"`
	Currency string    `json:"currency"`
	Balance  float64   `json:"balance"`
}

type Order struct {
	ID        uuid.UUID   `json:"id"`
	UserID    uuid.UUID   `json:"user_id"`
	Pair      string      `json:"pair"`
	Side      OrderSide   `json:"side"`
	Price     float64     `json:"price"`
	Quantity  float64     `json:"quantity"`
	Status    OrderStatus `json:"status"`
	CreatedAt time.Time   `json:"created_at"`
}

type Trade struct {
	ID          uuid.UUID `json:"id"`
	BuyOrderID  uuid.UUID `json:"buy_order_id"`
	SellOrderID uuid.UUID `json:"sell_order_id"`
	Price       float64   `json:"price"`
	Quantity    float64   `json:"quantity"`
	ExecutedAt  time.Time `json:"executed_at"`
}

// API Request/Response types
type CreateOrderRequest struct {
	UserID   uuid.UUID `json:"user_id"`
	Pair     string    `json:"pair"`
	Side     OrderSide `json:"side"`
	Price    float64   `json:"price"`
	Quantity float64   `json:"quantity"`
}

type BalanceResponse struct {
	UserID   uuid.UUID          `json:"user_id"`
	Balances map[string]float64 `json:"balances"`
}

type OrderBookEntry struct {
	Price    float64 `json:"price"`
	Quantity float64 `json:"quantity"`
}

type OrderBookResponse struct {
	Pair string           `json:"pair"`
	Bids []OrderBookEntry `json:"bids"`
	Asks []OrderBookEntry `json:"asks"`
}

type MatchResult struct {
	TradesExecuted int     `json:"trades_executed"`
	VolumeMatched  float64 `json:"volume_matched"`
}
