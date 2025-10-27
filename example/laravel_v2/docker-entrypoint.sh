#!/bin/sh
set -e

# Start the Inertia SSR server in the background if SSR is enabled
if [ "${INERTIA_SSR_ENABLED:-true}" = "true" ]; then
    echo "Starting Inertia SSR server..."
    cd /var/www/html
    node bootstrap/ssr/ssr.js &
    SSR_PID=$!
    
    # Wait a moment for SSR server to start
    sleep 2
    
    # Function to cleanup on exit
    cleanup() {
        echo "Shutting down SSR server..."
        kill $SSR_PID 2>/dev/null || true
        exit
    }
    trap cleanup TERM INT
fi

# Start Octane server
echo "Starting Laravel Octane..."
exec php -d variables_order=EGPCS artisan octane:start --server=swoole --host=0.0.0.0 --port=80