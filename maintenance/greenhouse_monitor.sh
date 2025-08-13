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
