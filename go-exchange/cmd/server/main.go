package main

import (
	"context"
	"log"
	"os"
	"os/signal"
	"runtime"
	"syscall"
	"time"

	"github.com/cryptox/go-exchange/internal/handler"
	"github.com/cryptox/go-exchange/internal/repository"
	"github.com/goccy/go-json"
	"github.com/gofiber/fiber/v2"
	"github.com/gofiber/fiber/v2/middleware/recover"
)

func main() {
	ctx := context.Background()

	// Database connection
	dbURL := os.Getenv("DATABASE_URL")
	if dbURL == "" {
		dbURL = "postgres://postgres:postgres@localhost:5432/cryptox?sslmode=disable"
	}

	db, err := repository.NewDB(ctx, dbURL)
	if err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}
	defer db.Close()

	// Setup Fiber app with optimized settings
	app := fiber.New(fiber.Config{
		// Prefork spawns multiple processes (one per CPU core)
		Prefork: true,

		// Server identification
		ServerHeader: "go-exchange",
		AppName:      "CryptoX Go Exchange v1.0.0",

		// Timeouts
		ReadTimeout:  5 * time.Second,
		WriteTimeout: 5 * time.Second,
		IdleTimeout:  120 * time.Second,

		// Body limits
		BodyLimit: 1024 * 1024, // 1MB

		// Performance optimizations
		DisableStartupMessage:     false,
		DisableDefaultDate:        true, // Small performance gain
		DisableDefaultContentType: false,
		DisableHeaderNormalizing:  true, // Faster header handling
		DisableKeepalive:          false,

		// Use go-json for JSON (3-4x faster than encoding/json)
		JSONEncoder: json.Marshal,
		JSONDecoder: json.Unmarshal,

		// Concurrency settings
		Concurrency: 256 * 1024, // Max concurrent connections
	})

	// Middleware
	app.Use(recover.New(recover.Config{
		EnableStackTrace: false, // Disable for performance
	}))

	// Setup handler
	h := handler.New(db)

	// Routes
	app.Get("/health", h.HealthCheck)
	app.Post("/orders", h.CreateOrder)
	app.Get("/orderbook/:pair", h.GetOrderBook)
	app.Get("/balance/:userId", h.GetBalance)
	app.Post("/trades/match", h.MatchOrders)

	// Get port
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	// Graceful shutdown
	go func() {
		if fiber.IsChild() {
			log.Printf("Go Exchange worker starting on port %s (PID: %d)", port, os.Getpid())
		} else {
			log.Printf("Go Exchange master starting on port %s with %d workers", port, runtime.NumCPU())
		}
		if err := app.Listen(":" + port); err != nil {
			log.Fatalf("Server error: %v", err)
		}
	}()

	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	log.Println("Shutting down server...")
	if err := app.ShutdownWithTimeout(30 * time.Second); err != nil {
		log.Fatalf("Server forced to shutdown: %v", err)
	}

	log.Println("Server exited")
}
