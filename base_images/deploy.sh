#!/bin/bash

# Base image versions
PHP_VERSION="8.3"
SWOOLE_VERSION="4.6"
REGISTRY="asia-southeast1-docker.pkg.dev/vortechron/base"
VERSION="1.0.0"

# # Build FPM image
# echo "Building FPM image..."
# docker build -t $REGISTRY/fpm:$VERSION-$PHP_VERSION-fpm-alpine \
#   --build-arg BASE_TAG=$PHP_VERSION-fpm-alpine \
#   -f Dockerfile.fpm .

# # Build Octane image  
# echo "Building Octane image..."
# docker build -t $REGISTRY/octane:$VERSION-$PHP_VERSION-fpm-alpine \
#   --platform linux/amd64 \
#   --build-arg BASE_TAG=php$PHP_VERSION-alpine \
#   -f Dockerfile.octane .

# # Build Worker image
echo "Building Worker image..."
docker build -t $REGISTRY/worker:$VERSION-$PHP_VERSION-cli-alpine \
  --platform linux/amd64 \
  --build-arg BASE_TAG=$PHP_VERSION-cli-alpine \
  -f Dockerfile.worker .

# Push images to registry
echo "Pushing images to registry..."
# docker push $REGISTRY/fpm:$VERSION-$PHP_VERSION-fpm-alpine
# docker push $REGISTRY/octane:$VERSION-$PHP_VERSION-fpm-alpine 
docker push $REGISTRY/worker:$VERSION-$PHP_VERSION-cli-alpine

echo "Deploy completed successfully!"
