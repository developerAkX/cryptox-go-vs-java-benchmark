package handler

import (
	"github.com/cryptox/go-exchange/internal/model"
	"github.com/cryptox/go-exchange/internal/repository"
	"github.com/gofiber/fiber/v2"
	"github.com/google/uuid"
)

type Handler struct {
	DB *repository.DB
}

func New(db *repository.DB) *Handler {
	return &Handler{DB: db}
}

// HealthCheck returns service status
func (h *Handler) HealthCheck(c *fiber.Ctx) error {
	return c.JSON(fiber.Map{
		"status":  "ok",
		"service": "go-exchange",
	})
}

// CreateOrder creates a new order
func (h *Handler) CreateOrder(c *fiber.Ctx) error {
	var req model.CreateOrderRequest
	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "invalid request body",
		})
	}

	order, err := h.DB.CreateOrder(c.UserContext(), req)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"error": "failed to create order",
		})
	}

	return c.Status(fiber.StatusCreated).JSON(order)
}

// GetOrderBook returns aggregated order book for a trading pair
func (h *Handler) GetOrderBook(c *fiber.Ctx) error {
	pair := c.Params("pair")
	if pair == "" {
		pair = "BTCUSDT"
	}

	orderBook, err := h.DB.GetOrderBook(c.UserContext(), pair)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"error": "failed to get order book",
		})
	}

	return c.JSON(orderBook)
}

// GetBalance returns user wallet balances
func (h *Handler) GetBalance(c *fiber.Ctx) error {
	userIDStr := c.Params("userId")
	userID, err := uuid.Parse(userIDStr)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "invalid user id",
		})
	}

	balance, err := h.DB.GetUserBalances(c.UserContext(), userID)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"error": "failed to get balance",
		})
	}

	return c.JSON(balance)
}

// MatchOrders attempts to match buy and sell orders
func (h *Handler) MatchOrders(c *fiber.Ctx) error {
	pair := c.Query("pair")
	if pair == "" {
		pair = "BTCUSDT"
	}

	result, err := h.DB.MatchOrders(c.UserContext(), pair)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"error": "failed to match orders",
		})
	}

	return c.JSON(result)
}
