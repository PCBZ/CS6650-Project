package handlers

import (
	"net/http"
	"strconv"

	"github.com/PCBZ/CS6650-Project/services/timeline-service/src/config"
	"github.com/PCBZ/CS6650-Project/services/timeline-service/src/fanout"
	"github.com/gin-gonic/gin"
)

type TimelineHandler struct {
	strategies map[string]fanout.Strategy
	config     *config.Config
}

func NewTimelineHandler(strategies map[string]fanout.Strategy, cfg *config.Config) *TimelineHandler {
	return &TimelineHandler{
		strategies: strategies,
		config:     cfg,
	}
}

// GetTimeline handles GET /api/timeline/:user_id
func (h *TimelineHandler) GetTimeline(c *gin.Context) {
	userIDStr := c.Param("user_id")
	userID, err := strconv.ParseInt(userIDStr, 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid user ID"})
		return
	}

	// Use algorithm from environment config
	algorithm := h.config.FanoutStrategy
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "50"))

	strategy, ok := h.strategies[algorithm]
	if !ok {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Configured strategy not available: " + algorithm})
		return
	}

	timeline, err := strategy.GetTimeline(userID, limit)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, timeline)
}

// Health check endpoint
func (h *TimelineHandler) Health(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{
		"status":               "healthy",
		"service":              "timeline-service",
		"current_strategy":     h.config.FanoutStrategy,
		"available_strategies": []string{"push", "pull", "hybrid"},
		"message_processing":   "SQS-based async processing",
		"endpoints": gin.H{
			"timeline": "GET /api/timeline/:user_id",
			"health":   "GET /api/health",
		},
	})
}
