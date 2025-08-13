#!/bin/bash
# Smart Greenhouse PostgreSQL Maintenance Script
# Uses .env file for database credentials

WORK_DIR="/home/elektro1/smart_greenhouse"
ENV_FILE="$WORK_DIR/.env"

# Check if .env file exists
if [ ! -f "$ENV_FILE" ]; then
    echo "ERROR: .env file not found at $ENV_FILE"
    exit 1
fi

# Load environment variables from .env file
set -a
source "$ENV_FILE"
set +a

LOG_FILE="/var/log/greenhouse_cleanup.log"
BACKUP_DIR="/opt/greenhouse/backups"

# Create backup directory
sudo mkdir -p "$BACKUP_DIR"
sudo chown elektro1:elektro1 "$BACKUP_DIR"

# Logging function
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Cleanup sensor data with retention policy
cleanup_sensor_data() {
    log_message "Starting sensor data cleanup..."
    
    # Count total records before cleanup
    total_before=$(PGPASSWORD="$DB_PASSWORD" psql -U "$DB_USER" -h "$DB_HOST" -d "$DB_NAME" -t -c \
        "SELECT COUNT(*) FROM sensor_readings;" | xargs)
    
    log_message "Total records before cleanup: $total_before"
    
    # STRATEGY 1: Keep only 1 record per hour for data > 7 days old
    log_message "Applying hourly retention for data > 7 days..."
    PGPASSWORD="$DB_PASSWORD" psql -U "$DB_USER" -h "$DB_HOST" -d "$DB_NAME" -c "
    WITH ranked_data AS (
        SELECT reading_id,
               ROW_NUMBER() OVER (
                   PARTITION BY device_id, DATE_TRUNC('hour', timestamp) 
                   ORDER BY timestamp
               ) AS rn
        FROM sensor_readings
        WHERE timestamp < NOW() - INTERVAL '7 days'
    )
    DELETE FROM sensor_readings
    WHERE reading_id IN (
        SELECT reading_id FROM ranked_data WHERE rn > 1
    );
    " 2>/dev/null
    
    # STRATEGY 2: Keep only 1 record per day for data > 90 days old
    log_message "Applying daily retention for data > 90 days..."
    PGPASSWORD="$DB_PASSWORD" psql -U "$DB_USER" -h "$DB_HOST" -d "$DB_NAME" -c "
    WITH ranked_daily AS (
        SELECT reading_id,
               ROW_NUMBER() OVER (
                   PARTITION BY device_id, DATE_TRUNC('day', timestamp) 
                   ORDER BY timestamp
               ) AS rn
        FROM sensor_readings
        WHERE timestamp < NOW() - INTERVAL '90 days'
    )
    DELETE FROM sensor_readings
    WHERE reading_id IN (
        SELECT reading_id FROM ranked_daily WHERE rn > 1
    );
    " 2>/dev/null
    
    # STRATEGY 3: Keep only 1 record per week for data > 1 year old
    log_message "Applying weekly retention for data > 1 year..."
    PGPASSWORD="$DB_PASSWORD" psql -U "$DB_USER" -h "$DB_HOST" -d "$DB_NAME" -c "
    WITH ranked_weekly AS (
        SELECT reading_id,
               ROW_NUMBER() OVER (
                   PARTITION BY device_id, DATE_TRUNC('week', timestamp) 
                   ORDER BY timestamp
               ) AS rn
        FROM sensor_readings
        WHERE timestamp < NOW() - INTERVAL '365 days'
    )
    DELETE FROM sensor_readings
    WHERE reading_id IN (
        SELECT reading_id FROM ranked_weekly WHERE rn > 1
    );
    " 2>/dev/null
    
    # Count total records after cleanup
    total_after=$(PGPASSWORD="$DB_PASSWORD" psql -U "$DB_USER" -h "$DB_HOST" -d "$DB_NAME" -t -c \
        "SELECT COUNT(*) FROM sensor_readings;" | xargs)
    
    deleted=$((total_before - total_after))
    log_message "Cleanup completed: $deleted records deleted, $total_after remaining"
}

# Vacuum database
vacuum_database() {
    log_message "Running VACUUM ANALYZE..."
    PGPASSWORD="$DB_PASSWORD" psql -U "$DB_USER" -h "$DB_HOST" -d "$DB_NAME" -c \
        "VACUUM ANALYZE sensor_readings;" 2>/dev/null
    log_message "VACUUM completed"
}

# Cleanup log files
cleanup_logs() {
    log_message "Cleaning up log files..."
    
    # PostgreSQL logs
    if [ -d "/var/log/postgresql" ]; then
        # Compress old logs
        find /var/log/postgresql -name "*.log" -mtime +7 -exec gzip {} \; 2>/dev/null || true
        # Remove very old compressed logs
        find /var/log/postgresql -name "*.gz" -mtime +30 -delete 2>/dev/null || true
        log_message "PostgreSQL logs cleaned"
    fi
    
    # Middleware log
    if [ -f "/var/log/middleware.log" ]; then
        # Truncate if larger than 50MB
        if [ $(stat -c%s "/var/log/middleware.log" 2>/dev/null || echo 0) -gt 52428800 ]; then
            tail -n 1000 "/var/log/middleware.log" > "/var/log/middleware.log.tmp"
            mv "/var/log/middleware.log.tmp" "/var/log/middleware.log"
            log_message "Middleware log truncated"
        fi
    fi
}

# Check disk usage
check_disk_usage() {
    USAGE=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
    log_message "Disk usage: $USAGE%"
    
    if [ "$USAGE" -gt 90 ]; then
        log_message "WARNING: High disk usage ($USAGE%) - running emergency cleanup"
        # Emergency: remove old backups
        find "$BACKUP_DIR" -name "*.sql.gz" -mtime +3 -delete 2>/dev/null || true
        # Emergency: aggressive log cleanup
        find /var/log/postgresql -name "*.log" -mtime +3 -delete 2>/dev/null || true
    fi
}

# Main execution
main() {
    log_message "========== Starting PostgreSQL maintenance =========="
    
    # Test database connection
    if ! PGPASSWORD="$DB_PASSWORD" psql -U "$DB_USER" -h "$DB_HOST" -d "$DB_NAME" -c '\q' 2>/dev/null; then
        log_message "ERROR: Cannot connect to database"
        exit 1
    fi
    
    log_message "Database connection: OK"
    
    # Run maintenance tasks
    check_disk_usage
    cleanup_sensor_data
    vacuum_database
    cleanup_logs
    
    # Final status
    db_size=$(PGPASSWORD="$DB_PASSWORD" psql -U "$DB_USER" -h "$DB_HOST" -d "$DB_NAME" -t -c \
        "SELECT pg_size_pretty(pg_database_size('$DB_NAME'));" 2>/dev/null | xargs)
    final_usage=$(df / | tail -1 | awk '{print $5}')
    
    log_message "========== Maintenance completed =========="
    log_message "Database size: $db_size"
    log_message "Disk usage: $final_usage"
}

# Execute based on parameter
case "${1:-auto}" in
    "auto")
        main
        ;;
    "data-only")
        log_message "Mode: data cleanup only"
        cleanup_sensor_data
        vacuum_database
        ;;
    "logs-only")
        log_message "Mode: log cleanup only"
        cleanup_logs
        ;;
    "check")
        log_message "Mode: status check only"
        check_disk_usage
        ;;
    *)
        echo "Usage: $0 {auto|data-only|logs-only|check}"
        exit 1
        ;;
esac
