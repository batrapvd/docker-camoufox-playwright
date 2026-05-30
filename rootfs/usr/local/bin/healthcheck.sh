#!/bin/bash
#
# Health check script for Camoufox + Playwright Docker container.
# This script verifies that the container services are running and responsive.
#
# Exit codes:
#   0: Healthy
#   1: Unhealthy
#

set -o pipefail

# Timeout for individual checks (in seconds)
TIMEOUT=5

# Helper function to log messages
log_info() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" >&2
}

# Helper function to check if a port is listening
check_port() {
    local port=$1
    local timeout=$2
    
    nc -z -w "$timeout" 127.0.0.1 "$port" 2>/dev/null
    return $?
}

# Helper function to check HTTP endpoint
check_http() {
    local url=$1
    local timeout=$2
    
    curl -s -f -m "$timeout" "$url" > /dev/null 2>&1
    return $?
}

# Check 1: Verify noVNC web interface is responsive (port 5800)
if check_port 5800 "$TIMEOUT"; then
    log_info "✓ noVNC interface (port 5800) is listening"
else
    log_info "✗ noVNC interface (port 5800) is not responding"
    exit 1
fi

# Check 2: Verify VNC server is running (port 5900)
if check_port 5900 "$TIMEOUT"; then
    log_info "✓ VNC server (port 5900) is listening"
else
    log_info "✗ VNC server (port 5900) is not responding"
    exit 1
fi

# Check 3: If running in Playwright server mode, check WebSocket endpoint
if [ "$CAMOUFOX_SERVER" = "1" ] || [ "$PLAYWRIGHT_SERVER" = "1" ]; then
    # The Playwright server typically listens on a dynamic port
    # Check if the process is running
    if pgrep -f "python.*camoufox" > /dev/null; then
        log_info "✓ Playwright/Camoufox server process is running"
    else
        log_info "✗ Playwright/Camoufox server process is not running"
        exit 1
    fi
else
    # Check 3: In GUI mode, verify that the display server is responsive
    # This is a lightweight check to ensure X11 is functioning
    if [ -n "$DISPLAY" ]; then
        if timeout "$TIMEOUT" xset q > /dev/null 2>&1; then
            log_info "✓ X11 display server is responsive"
        else
            log_info "✗ X11 display server is not responsive"
            exit 1
        fi
    fi
fi

# Check 4: Verify essential system services
# Check if init system is responsive (s6 or runit)
if [ -d /run/service ] || [ -d /etc/service ]; then
    log_info "✓ Service supervisor is active"
else
    log_info "✗ Service supervisor is not active"
    exit 1
fi

log_info "Container health check passed"
exit 0
