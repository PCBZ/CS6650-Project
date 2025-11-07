package models

type ErrorResponse struct {
	Success   bool   `json:"success"`
	Error     string `json:"error"`
	ErrorCode string `json:"error_code"`
}

const (
	ErrCodeInvalidRequest = "INVALID_REQUEST"
	ErrCodeInternalError  = "INTERNAL_ERROR"
	ErrCodeNotFound       = "NOT_FOUND"
)
