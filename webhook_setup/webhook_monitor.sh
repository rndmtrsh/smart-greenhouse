#!/bin/bash
# ========================
# Simple Webhook Monitor
# Monitor webhook activity and system health
# ========================

WORK_DIR="/home/elektro1/smart_greenhouse"
LOG_FILE="$WORK_DIR/logs/webhook.log"

# Load environment
source "$WORK_DIR/.env"

echo "🌱 Smart Greenhouse Webhook Monitor"
echo "=================================="
echo ""

show_status() {
    echo "📊 SYSTEM STATUS"
    echo "================"
    
    # Service status
    if systemctl is-active --quiet greenhouse-webhook-api.service; then
        echo "✅ Service: Running"
        uptime=$(systemctl show greenhouse-webhook-api.service --property=ActiveEnterTimestamp --value)
        echo "   Started: $uptime"
    else
        echo "❌ Service: Stopped"
    fi
    
    # Database status
    if PGPASSWORD="$DB_PASSWORD" psql -U "$DB_USER" -h "$DB_HOST" -d "$DB_NAME" -c '\q' 2>/dev/null; then
        echo "✅ Database: Connected"
        
        # Recent data count
        recent_1h=$(PGPASSWORD="$DB_PASSWORD" psql -U "$DB_USER" -h "$DB_HOST" -d "$DB_NAME" -t -c \
            "SELECT COUNT(*) FROM sensor_readings WHERE timestamp >= NOW() - INTERVAL '1 hour';" | xargs)
        recent_24h=$(PGPASSWORD="$DB_PASSWORD" psql -U "$DB_USER" -h "$DB_HOST" -d "$DB_NAME" -t -c \
            "SELECT COUNT(*) FROM sensor_readings WHERE timestamp >= NOW() - INTERVAL '24 hours';" | xargs)
        
        echo "   Data last 1h: $recent_1h readings"
        echo "   Data last 24h: $recent_24h readings"
    else
        echo "❌ Database: Connection failed"
    fi
    
    # External access
    if curl -s --max-time 5 "https://kedairekagreenhouse.my.id/webhook/test" >/dev/null 2>&1; then
        echo "✅ External access: Available"
    else
        echo "⚠️  External access: Check tunnel"
    fi
    
    echo ""
}

show_recent_activity() {
    echo "📈 RECENT WEBHOOK ACTIVITY"
    echo "=========================="
    
    if [ -f "$LOG_FILE" ]; then
        # Show last 10 webhook events
        echo "Last 10 webhook events:"
        grep -E "(✅|❌|📨)" "$LOG_FILE" | tail -10 || echo "No recent activity"
        
        echo ""
        echo "Activity summary (last 24 hours):"
        
        # Count successful webhooks
        success_count=$(grep "$(date '+%Y-%m-%d')" "$LOG_FILE" | grep -c "✅" || echo "0")
        error_count=$(grep "$(date '+%Y-%m-%d')" "$LOG_FILE" | grep -c "❌" || echo "0")
        
        echo "   ✅ Successful: $success_count"
        echo "   ❌ Errors: $error_count"
        
        # Device breakdown
        echo ""
        echo "Device activity (today):"
        grep "$(date '+%Y-%m-%d')" "$LOG_FILE" | grep "✅" | \
        sed -n 's/.*processed: \([A-Z0-9]*\).*/\1/p' | sort | uniq -c | \
        while read count device; do
            echo "   $device: $count webhooks"
        done
    else
        echo "📋 Log file not found: $LOG_FILE"
    fi
    
    echo ""
}

show_database_summary() {
    echo "💾 DATABASE SUMMARY"
    echo "=================="
    
    if PGPASSWORD="$DB_PASSWORD" psql -U "$DB_USER" -h "$DB_HOST" -d "$DB_NAME" -c '\q' 2>/dev/null; then
        
        # Device data summary
        echo "Recent data per device:"
        PGPASSWORD="$DB_PASSWORD" psql -U "$DB_USER" -h "$DB_HOST" -d "$DB_NAME" -c \
            "SELECT 
                d.code as device,
                COUNT(CASE WHEN sr.timestamp >= NOW() - INTERVAL '1 hour' THEN 1 END) as last_1h,
                COUNT(CASE WHEN sr.timestamp >= NOW() - INTERVAL '24 hours' THEN 1 END) as last_24h,
                MAX(sr.timestamp) as latest
            FROM devices d
            LEFT JOIN sensor_readings sr ON d.device_id = sr.device_id
            GROUP BY d.device_id, d.code
            ORDER BY d.code;"
        
        # Database size
        db_size=$(PGPASSWORD="$DB_PASSWORD" psql -U "$DB_USER" -h "$DB_HOST" -d "$DB_NAME" -t -c \
            "SELECT pg_size_pretty(pg_database_size('$DB_NAME'));" | xargs)
        echo ""
        echo "Database size: $db_size"
    else
        echo "❌ Cannot connect to database"
    fi
    
    echo ""
}

real_time_monitor() {
    echo "📡 REAL-TIME WEBHOOK MONITORING"
    echo "==============================="
    echo "Monitoring webhook log file..."
    echo "Press Ctrl+C to stop"
    echo ""
    
    if [ -f "$LOG_FILE" ]; then
        tail -f "$LOG_FILE" | while read line; do
            timestamp=$(echo "$line" | cut -d']' -f1 | tr -d '[')
            message=$(echo "$line" | cut -d']' -f2-)
            
            # Color code the output
            if echo "$line" | grep -q "✅"; then
                echo -e "\e[32m[$timestamp]\e[0m$message"  # Green
            elif echo "$line" | grep -q "❌"; then
                echo -e "\e[31m[$timestamp]\e[0m$message"  # Red
            elif echo "$line" | grep -q "📨"; then
                echo -e "\e[34m[$timestamp]\e[0m$message"  # Blue
            else
                echo -e "\e[37m[$timestamp]\e[0m$message"  # White
            fi
        done
    else
        echo "Log file not found: $LOG_FILE"
    fi
}

test_webhook() {
    echo "🧪 TESTING WEBHOOK"
    echo "=================="
    
    echo "Testing webhook endpoint..."
    
    response=$(curl -s -X POST "https://kedairekagreenhouse.my.id/webhook/antares" \
        -H "Content-Type: application/json" \
        -H "X-API-KEY: $API_KEY" \
        -d '{
            "deviceName": "CZ1",
            "data": "01F402BC006400C8",
            "timestamp": "'$(date -u +%Y-%m-%dT%H:%M:%S.000Z)'"
        }')
    
    if echo "$response" | grep -q '"status":"success"'; then
        echo "✅ Webhook test successful"
        echo "   Response: $response"
    else
        echo "❌ Webhook test failed"
        echo "   Response: $response"
    fi
    echo ""
}

# Main menu
case "${1:-menu}" in
    "status")
        show_status
        ;;
    "activity")
        show_recent_activity
        ;;
    "database")
        show_database_summary
        ;;
    "monitor")
        real_time_monitor
        ;;
    "test")
        test_webhook
        ;;
    "full")
        show_status
        show_recent_activity
        show_database_summary
        ;;
    *)
        echo "📋 Available commands:"
        echo "===================="
        echo "  $0 status     - Show system status"
        echo "  $0 activity   - Show recent webhook activity"
        echo "  $0 database   - Show database summary"
        echo "  $0 monitor    - Real-time log monitoring"
        echo "  $0 test       - Test webhook endpoint"
        echo "  $0 full       - Full system report"
        echo ""
        echo "Quick status check:"
        show_status
        ;;
esac