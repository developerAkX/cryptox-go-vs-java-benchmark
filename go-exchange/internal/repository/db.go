package repository

import (
	"context"
	"fmt"
	"runtime"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
)

type DB struct {
	Pool *pgxpool.Pool
}

func NewDB(ctx context.Context, connString string) (*DB, error) {
	config, err := pgxpool.ParseConfig(connString)
	if err != nil {
		return nil, fmt.Errorf("parse config: %w", err)
	}

	// Calculate connections per worker (for prefork mode)
	// Total Postgres connections = 500, divided by number of CPU workers
	numWorkers := runtime.NumCPU()
	if numWorkers < 1 {
		numWorkers = 1
	}

	maxConnsPerWorker := 400 / int32(numWorkers) // Leave some headroom
	if maxConnsPerWorker < 10 {
		maxConnsPerWorker = 10
	}
	minConnsPerWorker := maxConnsPerWorker / 4
	if minConnsPerWorker < 5 {
		minConnsPerWorker = 5
	}

	config.MaxConns = maxConnsPerWorker
	config.MinConns = minConnsPerWorker
	config.MaxConnLifetime = 30 * time.Minute
	config.MaxConnIdleTime = 5 * time.Minute
	config.HealthCheckPeriod = 1 * time.Minute

	// Connection acquisition settings
	config.ConnConfig.ConnectTimeout = 5 * time.Second

	pool, err := pgxpool.NewWithConfig(ctx, config)
	if err != nil {
		return nil, fmt.Errorf("create pool: %w", err)
	}

	if err := pool.Ping(ctx); err != nil {
		return nil, fmt.Errorf("ping: %w", err)
	}

	return &DB{Pool: pool}, nil
}

func (db *DB) Close() {
	db.Pool.Close()
}
