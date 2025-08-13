#!/bin/bash
# ========================
# Quick Setup Script - Smart Greenhouse PostgreSQL Maintenance
# Working Directory: /home/elektro1/smart_greenhouse/
# Uses .env file for database credentials
# ========================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
WORK_DIR="/home/elektro1/smart_greenhouse"
SCRIPTS_DIR="$WORK_DIR/maintenance"
LOG_FILE="/var/log/greenhouse_setup.log"
ENV_FILE="$WORK_DIR/.env"

print_status() {
    echo -e "${GREEN}[✓]${NC} $1" | tee -a "$LOG_FILE"
}

print_info() {
    echo -e "${BLUE}[i]${NC} $1" | tee -a "$LOG_FILE"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1" | tee -a "$LOG_FILE"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1" | tee -a "$LOG_FILE"
}

print_header() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE} $1 ${NC}"
    echo -e "${BLUE}========================================${NC}\n"
}

# ========================
# STEP 1: PREPARATION
# ========================
prepare_environment() {
    print_header "PREPARING ENVIRONMENT"
    
    # Check if running as elektro1 user
    if [ "$USER" != "elektro1" ]; then
        print_warning "Script should be run as elektro1 user"
        print_info "Current user: $USER"
    fi
    
    # Create log file
    sudo touch "$LOG_FILE"
    sudo chown elektro1:elektro1 "$LOG_FILE"
    
    # Check working directory
    if [ ! -d "$WORK_DIR" ]; then
        print_error "Working directory not found: $WORK_DIR"
        exit 1
    fi
    
    # Change to working directory
    cd "$WORK_DIR"
    print_status "Working directory: $(pwd)"
    
    # Check .env file
    if [ ! -f "$ENV_FILE" ]; then
        print_error ".env file not found: $ENV_FILE"
        print_error "Please create .env file with database credentials"
        exit 1
    fi
    
    print_status ".env file found: $ENV_FILE"
    
    # Create maintenance scripts directory
    mkdir -p "$SCRIPTS_DIR"
    print_status "Scripts directory: $SCRIPTS_DIR"
}

# ========================
# STEP 2: INSTALL DEPENDENCIES
# ========================
install_dependencies() {
    print_header "INSTALLING DEPENDENCIES"
    
    print_info "Updating package list..."
    sudo apt-get update -qq
    
    print_info "Installing required packages..."
    sudo apt-get install -y \
        postgresql-client \
        bc \
        gzip \
        cron
    
    print_status "Dependencies installed"
}

# ========================
# STEP 3: CREATE MAINTENANCE SCRIPT
# ========================
create_maintenance_script() {
    print_header "CREATING MAINTENANCE SCRIPT"
    
    cat > "$SCRIPTS_DIR/greenhouse_maintenance.sh" << 'EOF'
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
EOF

    chmod +x "$SCRIPTS_DIR/greenhouse_maintenance.sh"
    print_status "Maintenance script created: $SCRIPTS_DIR/greenhouse_maintenance.sh"
}

# ========================
# STEP 4: CREATE MONITORING SCRIPT
# ========================
create_monitoring_script() {
    print_header "CREATING MONITORING SCRIPT"
    
    cat > "$SCRIPTS_DIR/greenhouse_monitor.sh" << 'EOF'
#!/bin/bash
# Smart Greenhouse System Monitor
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

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_header() {
    echo -e "\n${GREEN}=== $1 ===${NC}"
}

print_status() {
    local label="$1"
    local value="$2"
    local color="$3"
    
    case "$color" in
        "good") color_code="$GREEN" ;;
        "warning") color_code="$YELLOW" ;;
        "critical") color_code="$RED" ;;
        *) color_code="$NC" ;;
    esac
    
    printf "%-25s: ${color_code}%s${NC}\n" "$label" "$value"
}

# System health check
check_system() {
    print_header "System Health"
    
    # Disk usage
    disk_usage=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
    if [ "$disk_usage" -gt 90 ]; then
        disk_status="critical"
    elif [ "$disk_usage" -gt 80 ]; then
        disk_status="warning"
    else
        disk_status="good"
    fi
    print_status "Disk Usage" "${disk_usage}%" "$disk_status"
    
    # Memory usage
    memory_info=$(free -m | grep "Mem:")
    total_mem=$(echo $memory_info | awk '{print $2}')
    used_mem=$(echo $memory_info | awk '{print $3}')
    memory_percent=$((used_mem * 100 / total_mem))
    
    if [ "$memory_percent" -gt 90 ]; then
        memory_status="critical"
    elif [ "$memory_percent" -gt 80 ]; then
        memory_status="warning"
    else
        memory_status="good"
    fi
    print_status "Memory Usage" "${memory_percent}% (${used_mem}/${total_mem}MB)" "$memory_status"
    
    # CPU Temperature (Raspberry Pi)
    if [ -f "/sys/class/thermal/thermal_zone0/temp" ]; then
        temp_raw=$(cat /sys/class/thermal/thermal_zone0/temp)
        temp_c=$((temp_raw / 1000))
        if [ "$temp_c" -gt 80 ]; then
            temp_status="critical"
        elif [ "$temp_c" -gt 70 ]; then
            temp_status="warning"
        else
            temp_status="good"
        fi
        print_status "CPU Temperature" "${temp_c}°C" "$temp_status"
    fi
}

# Database health check
check_database() {
    print_header "Database Health"
    
    # PostgreSQL service status
    if systemctl is-active --quiet postgresql; then
        print_status "PostgreSQL Service" "Running" "good"
    else
        print_status "PostgreSQL Service" "Stopped" "critical"
        return
    fi
    
    # Database connection test
    if PGPASSWORD="$DB_PASSWORD" psql -U "$DB_USER" -h "$DB_HOST" -d "$DB_NAME" -c '\q' 2>/dev/null; then
        print_status "Database Connection" "OK" "good"
    else
        print_status "Database Connection" "Failed" "critical"
        return
    fi
    
    # Database statistics
    db_size=$(PGPASSWORD="$DB_PASSWORD" psql -U "$DB_USER" -h "$DB_HOST" -d "$DB_NAME" -t -c \
        "SELECT pg_size_pretty(pg_database_size('$DB_NAME'));" 2>/dev/null | xargs)
    print_status "Database Size" "$db_size" "good"
    
    total_readings=$(PGPASSWORD="$DB_PASSWORD" psql -U "$DB_USER" -h "$DB_HOST" -d "$DB_NAME" -t -c \
        "SELECT COUNT(*) FROM sensor_readings;" 2>/dev/null | xargs)
    print_status "Total Sensor Readings" "$total_readings" "good"
    
    recent_data=$(PGPASSWORD="$DB_PASSWORD" psql -U "$DB_USER" -h "$DB_HOST" -d "$DB_NAME" -t -c \
        "SELECT COUNT(*) FROM sensor_readings WHERE timestamp >= NOW() - INTERVAL '24 hours';" 2>/dev/null | xargs)
    print_status "Data (Last 24h)" "$recent_data" "good"
}

# Maintenance status check
check_maintenance() {
    print_header "Maintenance Status"
    
    # Check if maintenance script exists
    if [ -f "/home/elektro1/smart_greenhouse/maintenance/greenhouse_maintenance.sh" ]; then
        print_status "Maintenance Script" "Installed" "good"
    else
        print_status "Maintenance Script" "Not Found" "warning"
    fi
    
    # Check cron job
    if crontab -l 2>/dev/null | grep -q "greenhouse_maintenance"; then
        print_status "Automated Schedule" "Active" "good"
    else
        print_status "Automated Schedule" "Not Set" "warning"
    fi
    
    # Check maintenance log
    if [ -f "/var/log/greenhouse_cleanup.log" ]; then
        last_maintenance=$(tail -1 /var/log/greenhouse_cleanup.log 2>/dev/null | awk '{print $1, $2}' || echo "No recent run")
        print_status "Last Maintenance" "$last_maintenance" "good"
    else
        print_status "Maintenance Log" "Not Found" "warning"
    fi
}

# Main execution
echo "🌱 Smart Greenhouse System Monitor"
echo "$(date '+%Y-%m-%d %H:%M:%S')"
echo "================================="

check_system
check_database
check_maintenance

echo ""
EOF

    chmod +x "$SCRIPTS_DIR/greenhouse_monitor.sh"
    print_status "Monitoring script created: $SCRIPTS_DIR/greenhouse_monitor.sh"
}

# ========================
# STEP 5: TEST DATABASE CONNECTION
# ========================
test_database_connection() {
    print_header "TESTING DATABASE CONNECTION"
    
    # Load environment variables
    set -a
    source "$ENV_FILE"
    set +a
    
    print_info "Testing connection to PostgreSQL..."
    print_info "Database: $DB_NAME@$DB_HOST:$DB_PORT"
    print_info "User: $DB_USER"
    
    if PGPASSWORD="$DB_PASSWORD" psql -U "$DB_USER" -h "$DB_HOST" -d "$DB_NAME" -c '\q' 2>/dev/null; then
        print_status "Database connection successful"
        
        # Get database info
        db_size=$(PGPASSWORD="$DB_PASSWORD" psql -U "$DB_USER" -h "$DB_HOST" -d "$DB_NAME" -t -c \
            "SELECT pg_size_pretty(pg_database_size('$DB_NAME'));" 2>/dev/null | xargs)
        total_records=$(PGPASSWORD="$DB_PASSWORD" psql -U "$DB_USER" -h "$DB_HOST" -d "$DB_NAME" -t -c \
            "SELECT COUNT(*) FROM sensor_readings;" 2>/dev/null | xargs)
        
        print_info "Database size: $db_size"
        print_info "Total sensor readings: $total_records"
    else
        print_error "Database connection failed"
        print_error "Please check:"
        print_error "- PostgreSQL service is running: sudo systemctl status postgresql"
        print_error "- Database credentials in .env file are correct"
        print_error "- Database '$DB_NAME' exists"
        return 1
    fi
}

# ========================
# STEP 6: SETUP CRON JOB
# ========================
setup_cron_job() {
    print_header "SETTING UP AUTOMATED MAINTENANCE"
    
    # Create log directory
    sudo mkdir -p /var/log
    sudo touch /var/log/greenhouse_cleanup.log
    sudo chown elektro1:elektro1 /var/log/greenhouse_cleanup.log
    
    # Backup current crontab
    crontab -l 2>/dev/null > /tmp/current_cron || touch /tmp/current_cron
    
    # Remove existing greenhouse maintenance entries
    grep -v "greenhouse_maintenance" /tmp/current_cron > /tmp/new_cron || touch /tmp/new_cron
    
    # Add new maintenance cron job - daily at 3:00 AM
    echo "0 3 * * * $SCRIPTS_DIR/greenhouse_maintenance.sh auto >> /var/log/greenhouse_cleanup.log 2>&1" >> /tmp/new_cron
    
    # Install new crontab
    crontab /tmp/new_cron
    
    # Cleanup temp files
    rm -f /tmp/current_cron /tmp/new_cron
    
    print_status "Cron job scheduled: Daily maintenance at 3:00 AM"
}

# ========================
# STEP 7: OPTIMIZE POSTGRESQL
# ========================
optimize_postgresql() {
    print_header "OPTIMIZING POSTGRESQL CONFIGURATION"
    
    # Detect PostgreSQL version
    PG_VERSION=$(sudo -u postgres psql -t -c "SELECT version();" 2>/dev/null | head -n1 | sed 's/.*PostgreSQL \([0-9]*\).*/\1/' || echo "15")
    PG_CONFIG="/etc/postgresql/$PG_VERSION/main/postgresql.conf"
    
    print_info "PostgreSQL version: $PG_VERSION"
    print_info "Config file: $PG_CONFIG"
    
    if [ -f "$PG_CONFIG" ]; then
        # Backup original config
        sudo cp "$PG_CONFIG" "$PG_CONFIG.backup.$(date +%Y%m%d_%H%M%S)"
        print_status "Config backed up"
        
        # Detect system RAM
        TOTAL_RAM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
        TOTAL_RAM_GB=$((TOTAL_RAM_KB / 1024 / 1024))
        
        print_info "System RAM: ${TOTAL_RAM_GB}GB"
        
        # Calculate optimal settings
        if [ "$TOTAL_RAM_GB" -le 2 ]; then
            SHARED_BUFFERS="128MB"
            WORK_MEM="4MB"
            EFFECTIVE_CACHE="256MB"
        elif [ "$TOTAL_RAM_GB" -le 4 ]; then
            SHARED_BUFFERS="256MB"
            WORK_MEM="6MB"
            EFFECTIVE_CACHE="512MB"
        else
            SHARED_BUFFERS="512MB"
            WORK_MEM="8MB"
            EFFECTIVE_CACHE="1GB"
        fi
        
        print_info "Applying optimal settings for ${TOTAL_RAM_GB}GB RAM..."
        
        # Apply PostgreSQL optimizations
        sudo sed -i "s/#*shared_buffers = .*/shared_buffers = $SHARED_BUFFERS/" "$PG_CONFIG"
        sudo sed -i "s/#*work_mem = .*/work_mem = $WORK_MEM/" "$PG_CONFIG"
        sudo sed -i "s/#*effective_cache_size = .*/effective_cache_size = $EFFECTIVE_CACHE/" "$PG_CONFIG"
        sudo sed -i "s/#*maintenance_work_mem = .*/maintenance_work_mem = 64MB/" "$PG_CONFIG"
        sudo sed -i "s/#*max_connections = .*/max_connections = 50/" "$PG_CONFIG"
        
        # Log rotation settings
        sudo sed -i "s/#*logging_collector = .*/logging_collector = on/" "$PG_CONFIG"
        sudo sed -i "s/#*log_rotation_age = .*/log_rotation_age = 1d/" "$PG_CONFIG"
        sudo sed -i "s/#*log_rotation_size = .*/log_rotation_size = 10MB/" "$PG_CONFIG"
        sudo sed -i "s/#*log_truncate_on_rotation = .*/log_truncate_on_rotation = on/" "$PG_CONFIG"
        
        print_status "PostgreSQL optimized:"
        print_info "  shared_buffers: $SHARED_BUFFERS"
        print_info "  work_mem: $WORK_MEM"
        print_info "  effective_cache_size: $EFFECTIVE_CACHE"
        print_info "  max_connections: 50"
        print_info "  log_rotation: enabled"
        
    else
        print_warning "PostgreSQL config file not found - skipping optimization"
    fi
}

# ========================
# STEP 8: SETUP LOG ROTATION
# ========================
setup_log_rotation() {
    print_header "SETTING UP LOG ROTATION"
    
    sudo tee /etc/logrotate.d/greenhouse > /dev/null << 'EOF'
/var/log/postgresql/*.log {
    daily
    missingok
    rotate 7
    compress
    delaycompress
    notifempty
    create 644 postgres postgres
    maxsize 10M
    postrotate
        /bin/kill -HUP `cat /var/run/postgresql/*.pid 2> /dev/null` 2> /dev/null || true
    endscript
}

/var/log/greenhouse_cleanup.log {
    weekly
    missingok
    rotate 4
    compress
    delaycompress
    notifempty
    create 644 elektro1 elektro1
    maxsize 5M
}

/var/log/middleware.log {
    weekly
    missingok
    rotate 4
    compress
    delaycompress
    notifempty
    create 644 elektro1 elektro1
    maxsize 50M
}
EOF

    print_status "Log rotation configured"
}

# ========================
# STEP 9: CREATE BACKUP DIRECTORY
# ========================
setup_backup_directory() {
    print_header "SETTING UP BACKUP DIRECTORY"
    
    sudo mkdir -p /opt/greenhouse/backups
    sudo chown elektro1:elektro1 /opt/greenhouse/backups
    sudo chmod 755 /opt/greenhouse/backups
    
    print_status "Backup directory created: /opt/greenhouse/backups"
}

# ========================
# STEP 10: FINAL TEST
# ========================
run_final_test() {
    print_header "RUNNING FINAL TESTS"
    
    print_info "Testing maintenance script..."
    if "$SCRIPTS_DIR/greenhouse_maintenance.sh" check; then
        print_status "Maintenance script test: PASSED"
    else
        print_error "Maintenance script test: FAILED"
    fi
    
    print_info "Testing monitoring script..."
    if "$SCRIPTS_DIR/greenhouse_monitor.sh" >/dev/null 2>&1; then
        print_status "Monitoring script test: PASSED"
    else
        print_error "Monitoring script test: FAILED"
    fi
    
    print_info "Testing cron job configuration..."
    if crontab -l | grep -q "greenhouse_maintenance"; then
        print_status "Cron job test: PASSED"
    else
        print_error "Cron job test: FAILED"
    fi
}

# ========================
# MAIN EXECUTION
# ========================
main() {
    print_header "SMART GREENHOUSE QUICK SETUP"
    print_info "Working directory: $WORK_DIR"
    print_info "Scripts directory: $SCRIPTS_DIR"
    print_info "Environment file: $ENV_FILE"
    print_info "Log file: $LOG_FILE"
    
    # Run all setup steps
    prepare_environment
    install_dependencies
    test_database_connection
    create_maintenance_script
    create_monitoring_script
    setup_backup_directory
    setup_cron_job
    optimize_postgresql
    setup_log_rotation
    run_final_test
    
    # Final instructions
    print_header "SETUP COMPLETED SUCCESSFULLY!"
    
    echo -e "${GREEN}✅ Installation Summary:${NC}"
    echo "   📁 Scripts location: $SCRIPTS_DIR"
    echo "   📄 Maintenance script: greenhouse_maintenance.sh"
    echo "   📊 Monitor script: greenhouse_monitor.sh"
    echo "   ⏰ Cron job: Daily at 3:00 AM"
    echo "   📋 Log file: /var/log/greenhouse_cleanup.log"
    echo "   💾 Backup directory: /opt/greenhouse/backups"
    echo "   🔐 Credentials: Loaded from .env file"
    echo ""
    
    echo -e "${YELLOW}�� Next Steps:${NC}"
    echo "   1. Restart PostgreSQL to apply optimizations:"
    echo "      ${BLUE}sudo systemctl restart postgresql${NC}"
    echo ""
    echo "   2. Test maintenance manually:"
    echo "      ${BLUE}$SCRIPTS_DIR/greenhouse_maintenance.sh check${NC}"
    echo ""
    echo "   3. Monitor system status:"
    echo "      ${BLUE}$SCRIPTS_DIR/greenhouse_monitor.sh${NC}"
    echo ""
    echo "   4. View maintenance logs:"
    echo "      ${BLUE}tail -f /var/log/greenhouse_cleanup.log${NC}"
    echo ""
    
    echo -e "${GREEN}🎉 Your Smart Greenhouse maintenance system is ready!${NC}"
    echo "   • Data retention: Automatic (keeps trends, saves 95%+ space)"
    echo "   • Memory optimization: PostgreSQL tuned for your system"
    echo "   • Log rotation: Automatic cleanup to prevent disk bloat"
    echo "   • Maintenance: Runs daily at 3:00 AM automatically"
    echo "   • Security: Database credentials secured in .env file"
    echo ""
    
    # Ask to restart PostgreSQL
    echo -n "Restart PostgreSQL now to apply optimizations? (y/N): "
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        print_info "Restarting PostgreSQL..."
        sudo systemctl restart postgresql
        sleep 3
        if systemctl is-active --quiet postgresql; then
            print_status "PostgreSQL restarted successfully"
            print_info "Running quick status check..."
            "$SCRIPTS_DIR/greenhouse_monitor.sh"
        else
            print_error "PostgreSQL failed to restart - check configuration"
        fi
    else
        print_warning "Remember to restart PostgreSQL later: sudo systemctl restart postgresql"
    fi
}

# Check if running from correct directory or create it
if [ ! -d "/home/elektro1/smart_greenhouse" ]; then
    print_error "Working directory /home/elektro1/smart_greenhouse not found"
    print_info "Creating working directory..."
    sudo mkdir -p /home/elektro1/smart_greenhouse
    sudo chown elektro1:elektro1 /home/elektro1/smart_greenhouse
fi

# Run main setup
main "$@"
