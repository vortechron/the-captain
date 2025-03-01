# Docker Base Images Deployment Guide

This guide explains how to use the `deploy.sh` script to build and deploy Docker base images for PHP applications.

## Overview

The `deploy.sh` script builds and pushes three Docker base images to a Google Container Registry:

1. FPM Image - For PHP-FPM applications
2. Octane Image - For Laravel Octane applications using Swoole
3. Worker Image - For CLI/Worker applications

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
