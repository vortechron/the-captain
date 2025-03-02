# Docker Base Images Deployment Guide

This guide explains how to use the `deploy.sh` script to build and deploy Docker base images for PHP and Golang applications.

## Overview

The `deploy.sh` script builds and pushes Docker base images to a Google Container Registry:

1. FPM Image - For PHP-FPM applications
2. Octane Image - For Laravel Octane applications using Swoole
3. Worker Image - For CLI/Worker applications
4. Golang Image - For Golang applications, particularly those using the Gin framework

## Prerequisites

- Docker installed and configured
- Access to the Google Container Registry (GCR)
- Docker authentication configured for GCR

## Configuration

The script uses the following variables that can be modified:
```bash
PHP_VERSION="8.1"
SWOOLE_VERSION="4.6"
REGISTRY="asia-southeast1-docker.pkg.dev/vortechron/base"
VERSION="1.0.0"
```

## Golang Base Image

The Golang base image is designed for building and running Go applications, particularly those using the Gin framework. It uses a multi-stage build process to create a minimal final image.

### Features

- Based on Alpine Linux for a small footprint
- Multi-stage build for optimized image size
- Non-root user for improved security
- Pre-installed certificates and timezone data
- Ready for Go applications

### Usage

To use this base image in your Dockerfile:

```dockerfile
FROM asia-southeast1-docker.pkg.dev/vortechron/base/golang:1.0.0

WORKDIR /app

# Copy go.mod and go.sum files
COPY go.mod go.sum* ./

# Download dependencies
RUN go mod download

# Copy the source code
COPY . .

# Build the application
RUN CGO_ENABLED=0 GOOS=linux go build -o app .

# Expose the application port
EXPOSE 8080

# Run the application
CMD ["./app"]
```

### Building and Publishing

To build and publish this base image:

```bash
cd base_images
./deploy.sh Dockerfile.golang golang 1.0.0
```

This will build and push the image to your container registry.
