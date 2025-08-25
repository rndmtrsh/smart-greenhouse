#!/bin/bash
# ========================
# Webhook System Verification Script
# Test all components are working
# ========================

WORK_DIR="/home/elektro1/smart_greenhouse"

echo "🔍 Smart Greenhouse Webhook System Verification"
echo "==============================================="
echo ""

# Load environment variables
if [ -f "$WORK_DIR/.env" ]; then
    source "$WORK_DIR/.env"
else
    echo "❌ .env file not found"
    exit 1
fi

print_test() {
    echo "🧪 TEST $1: $2"
    echo "$(printf '%.0s-' {1..40})"
}

print_pass() {
    echo "✅ PASS: $1"
}

print_fail() {
    echo "❌ FAIL: $1"
}

print_info() {
    echo "ℹ️  $1"
}

# Test 1: File Structure
print_test "1" "File Structure"
echo ""

required_files=(
    "webhook/__init__.py"
    "webhook/webhook_config.py"
    "webhook/webhook_auth.py"
    "webhook/webhook_utils.py"
    "webhook/webhook_handler.py"
    "webhook/webhook_routes.py"
    "logs/webhook.log"
    "flask_api/app.py"
    ".env"
)

all_files_exist=true
for file in "${required_files[@]}"; do
    if [ -f "$WORK_DIR/$file" ]; then
        print_pass "$file exists"
    else
        print_fail "$file missing"
        all_files_exist=false
    fi
done

if [ "$all_files_exist" = true ]; then
    print_pass "All required files present"
else
    print_fail "Some files are missing"
fi
echo ""

# Test 2: Python Environment
print_test "2" "Python Environment"
echo ""

cd "$WORK_DIR"
source venv/bin/activate

if python -c "
import sys
sys.path.insert(0, '.')
from webhook import webhook_handler, register_webhook_routes, WebhookConfig
print('Python imports: OK')
" 2>/dev/null; then
    print_pass "Python imports working"
else
    print_fail "Python import issues"
    python -c "
import sys
sys.path.insert(0, '.')
from webhook import webhook_handler, register_webhook_routes, WebhookConfig
"
fi

deactivate
echo ""

# Test 3: Configuration
print_test "3" "Configuration"
echo ""

if [ -n "$API_KEY" ]; then
    print_pass "API_KEY is set (${API_KEY:0:10}...)"
else
    print_fail "API_KEY is not set"
fi

if [ -n "$DATABASE_URL" ]; then
    print_pass "DATABASE_URL is set"
else
    print_fail "DATABASE_URL is not set"
fi

if [ -n "$WEBHOOK_RATE_LIMIT" ]; then
    print_pass "WEBHOOK_RATE_LIMIT is set ($WEBHOOK_RATE_LIMIT)"
else
    print_fail "WEBHOOK_RATE_LIMIT is not set"
fi
echo ""

# Test 4: Database Connection
print_test "4" "Database Connection"
echo ""

if PGPASSWORD="$DB_PASSWORD" psql -U "$DB_USER" -h "$DB_HOST" -d "$DB_NAME" -c '\q' 2>/dev/null; then
    print_pass "Database connection successful"
    
    # Check required tables
    tables_exist=$(PGPASSWORD="$DB_PASSWORD" psql -U "$DB_USER" -h "$DB_HOST" -d "$DB_NAME" -t -c \
        "SELECT COUNT(*) FROM information_schema.tables WHERE table_name IN ('devices', 'sensor_readings', 'zones', 'plants');" | xargs)
    
    if [ "$tables_exist" = "4" ]; then
        print_pass "All required database tables exist"
    else
        print_fail "Some database tables are missing ($tables_exist/4 found)"
    fi
else
    print_fail "Database connection failed"
fi
echo ""

# Test 5: Service Status
print_test "5" "Service Status"
echo ""

if systemctl is-active --quiet greenhouse-webhook-api.service; then
    print_pass "Webhook API service is running"
    
    uptime=$(systemctl show greenhouse-webhook-api.service --property=ActiveEnterTimestamp --value)
    print_info "Service uptime: $uptime"
else
    print_fail "Webhook API service is not running"
    print_info "Start with: sudo systemctl start greenhouse-webhook-api.service"
fi
echo ""

# Test 6: Local Endpoints
print_test "6" "Local Endpoints"
echo ""

# Test health endpoint
if curl -s --max-time 5 "http://localhost:5000/health" | grep -q "healthy"; then
    print_pass "Health endpoint working"
else
    print_fail "Health endpoint not responding"
fi

# Test webhook test endpoint
if curl -s --max-time 5 "http://localhost:5000/webhook/test" | grep -q "active"; then
    print_pass "Webhook test endpoint working"
else
    print_fail "Webhook test endpoint not responding"
fi

# Test webhook status
if curl -s --max-time 5 "http://localhost:5000/webhook/status" | grep -q "status"; then
    print_pass "Webhook status endpoint working"
else
    print_fail "Webhook status endpoint not responding"
fi
echo ""

# Test 7: External Access
print_test "7" "External Access (Cloudflare Tunnel)"
echo ""

if curl -s --max-time 10 "https://kedairekagreenhouse.my.id/health" >/dev/null 2>&1; then
    print_pass "External domain accessible"
    
    if curl -s --max-time 10 "https://kedairekagreenhouse.my.id/webhook/test" | grep -q "active"; then
        print_pass "External webhook endpoint working"
        print_info "🎯 Ready for Antares subscribers!"
    else
        print_fail "External webhook endpoint issues"
    fi
else
    print_fail "External domain not accessible"
    print_info "Check Cloudflare tunnel: cloudflared tunnel list"
fi
echo ""

# Test 8: Webhook Processing
print_test "8" "Webhook Data Processing"
echo ""

# Test with sample data
webhook_response=$(curl -s --max-time 10 -X POST "http://localhost:5000/webhook/antares" \
    -H "Content-Type: application/json" \
    -H "X-API-KEY: $API_KEY" \
    -d '{
        "deviceName": "CZ1",
        "data": "01F402BC006400C8",
        "timestamp": "'$(date -u +%Y-%m-%dT%H:%M:%S.000Z)'"
    }' 2>/dev/null)

if echo "$webhook_response" | grep -q '"status":"success"'; then
    print_pass "Webhook data processing working"
    
    # Check if data was saved to database
    recent_data=$(PGPASSWORD="$DB_PASSWORD" psql -U "$DB_USER" -h "$DB_HOST" -d "$DB_NAME" -t -c \
        "SELECT COUNT(*) FROM sensor_readings WHERE timestamp >= NOW() - INTERVAL '5 minutes';" 2>/dev/null | xargs)
    
    if [ "$recent_data" -gt 0 ]; then
        print_pass "Test data saved to database ($recent_data recent records)"
    else
        print_fail "Test data not found in database"
    fi
else
    print_fail "Webhook data processing failed"
    print_info "Response: $webhook_response"
fi
echo ""

# Test 9: Device Validation
print_test "9" "Device Configuration"
echo ""

# Test device validation with known devices
known_devices=("CZ1" "CZ2" "CZ3" "CZ4" "MZ1" "MZ2" "SZ12" "SZ3" "SZ4" "GZ1" "Monitoring_Hidroponik")
unknown_count=0

for device in "${known_devices[@]}"; do
    device_exists=$(PGPASSWORD="$DB_PASSWORD" psql -U "$DB_USER" -h "$DB_HOST" -d "$DB_NAME" -t -c \
        "SELECT COUNT(*) FROM devices WHERE code = '$device';" 2>/dev/null | xargs)
    
    if [ "$device_exists" = "1" ]; then
        print_pass "Device $device exists in database"
    else
        print_fail "Device $device missing from database"
        unknown_count=$((unknown_count + 1))
    fi
done

if [ "$unknown_count" = "0" ]; then
    print_pass "All devices properly configured"
else
    print_fail "$unknown_count devices missing from database"
fi
echo ""

# Summary
echo "📊 VERIFICATION SUMMARY"
echo "======================"
echo ""

# Count passes and fails
total_tests=9
pass_count=$(echo "$output" | grep -c "✅ PASS" 2>/dev/null || echo "0")
fail_count=$((total_tests - pass_count))

if [ "$fail_count" = "0" ]; then
    echo "🎉 ALL TESTS PASSED! System is ready for production."
    echo ""
    echo "📋 Next Steps:"
    echo "1. Create Antares subscribers using the commands from setup guide"
    echo "2. Monitor webhook logs: tail -f logs/webhook.log"  
    echo "3. Test with real sensor data"
    echo "4. Disable old polling system once confirmed working"
    echo ""
    echo "🔗 Your webhook URL: https://kedairekagreenhouse.my.id/webhook/antares"
    echo "🔑 Authentication header: X-API-KEY: $API_KEY"
elif [ "$fail_count" -le 2 ]; then
    echo "⚠️  MINOR ISSUES DETECTED ($fail_count failed tests)"
    echo "System should work but some features may need attention."
    echo ""
    echo "📋 Review failed tests above and fix issues."
else
    echo "❌ MAJOR ISSUES DETECTED ($fail_count failed tests)"
    echo "System needs attention before production use."
    echo ""
    echo "📋 Fix the failed tests above before proceeding."
fi

echo ""
echo "📊 Test Results: $pass_count/$total_tests passed"
echo "🔍 For detailed logs: journalctl -u greenhouse-webhook-api.service"