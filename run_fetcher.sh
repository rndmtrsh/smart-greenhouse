#!/bin/bash
# Optimized wrapper script with resource monitoring

WORK_DIR="/home/elektro1/smart_greenhouse"
LOG_FILE="$WORK_DIR/middleware.log"
LOCK_FILE="/tmp/greenhouse_fetch.lock"

# Function to cleanup on exit
cleanup() {
    rm -f "$LOCK_FILE"
    # Force cleanup of any stuck Python processes
    pkill -f "fetch_antares.py" 2>/dev/null || true
}

# Set trap for cleanup
trap cleanup EXIT INT TERM

# Check if already running (prevent accumulation)
if [ -f "$LOCK_FILE" ]; then
    pid=$(cat "$LOCK_FILE" 2>/dev/null)
    if ps -p "$pid" > /dev/null 2>&1; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Fetch already running (PID: $pid), skipping..." >> "$LOG_FILE"
        exit 0
    else
        rm -f "$LOCK_FILE"
    fi
fi

# Create lock file
echo $$ > "$LOCK_FILE"

# Change to work directory
cd "$WORK_DIR"

# Check memory before running
available_mem=$(free -m | awk 'NR==2{printf "%.0f", $7}')
if [ "$available_mem" -lt 100 ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Low memory ($available_mem MB), skipping fetch" >> "$LOG_FILE"
    exit 0
fi

# Activate virtual environment with timeout
timeout 5s source venv/bin/activate || {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Failed to activate venv" >> "$LOG_FILE"
    exit 1
}

# Set environment variables
export PYTHONPATH="$WORK_DIR"

# Log start
echo "$(date '+%Y-%m-%d %H:%M:%S') - Starting data fetch (PID: $$)..." >> "$LOG_FILE"

# Run fetch script with timeout and nice priority
timeout 120s nice -n 10 python fetch_antares/fetch_antares.py >> "$LOG_FILE" 2>&1
exit_code=$?

# Log completion
if [ $exit_code -eq 0 ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Data fetch completed successfully" >> "$LOG_FILE"
elif [ $exit_code -eq 124 ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Data fetch timed out (>120s)" >> "$LOG_FILE"
else
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Data fetch failed (exit code: $exit_code)" >> "$LOG_FILE"
fi

# Deactivate virtual environment
deactivate

# Cleanup
cleanup
