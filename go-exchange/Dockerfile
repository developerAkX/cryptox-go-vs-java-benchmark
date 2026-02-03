# Build stage
FROM golang:1.22-alpine AS builder

WORKDIR /app

# Copy go mod files
COPY go.mod go.sum ./
RUN go mod download

# Copy source code
COPY . .

# Build binary (no CGO needed with go-json)
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-w -s" -o /go-exchange ./cmd/server

# Final stage - alpine for prefork support (needs process forking)
FROM alpine:3.19

# Add ca-certificates for HTTPS and timezone data
RUN apk add --no-cache ca-certificates tzdata

COPY --from=builder /go-exchange /go-exchange

EXPOSE 8080

ENTRYPOINT ["/go-exchange"]
