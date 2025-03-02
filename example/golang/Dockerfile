FROM test-golang:1.0.0
# FROM asia-southeast1-docker.pkg.dev/vortechron/base/golang:1.0.0

WORKDIR /app

# Copy go.mod and go.sum files
COPY go.mod go.sum* ./

# Download dependencies
RUN go mod download

# Copy the source code
COPY . .

# Build the application
RUN CGO_ENABLED=0 GOOS=linux go build -o app .

# Use the non-root user from the base image
USER appuser

# Expose the application port
EXPOSE 8080

# Run the application
CMD ["./app"] 