#!/bin/bash
# ========================
# Complete Webhook Setup Guide
# Real-time data collection from Antares
# ========================

WORK_DIR="/home/elektro1/smart_greenhouse"

echo "🌱 Smart Greenhouse Webhook Setup Guide"
echo "======================================="
echo ""

print_step() {
    echo "📋 STEP $1: $2"
    echo "$(printf '%.0s-' {1..50})"
}

print_info() {
    echo "ℹ️  $1"
}

print_success() {
    echo "✅ $1"
}

print_warning() {
    echo "⚠️  $1"
}

# ========================
# STEP 1: UNDERSTANDING THE SYSTEM
# ========================
print_step "1" "UNDERSTANDING HOW WEBHOOKS WORK"
echo ""
echo "🔄 CURRENT SYSTEM (Polling):"
echo "Your Server ──(every 5 min)──▶ Antares API ──▶ Get Data ──▶ Save to DB"
echo "❌ Problem: 5-minute delay, constant server requests"
echo ""
echo "🚀 NEW SYSTEM (Webhooks):"
echo "Sensor ──▶ Antares ──(instantly)──▶ Your Webhook ──▶ Save to DB"
echo "✅ Benefits: Real-time data, no polling overhead"
echo ""

print_step "2" "YOUR ANTARES APPLICATIONS"
echo ""
echo "Based on your setup, you have these applications:"
echo "📱 CABAI           → Devices: CZ1, CZ2, CZ3, CZ4"
echo "📱 MELON           → Devices: MZ1, MZ2"
echo "📱 SELADA          → Devices: SZ12, SZ3, SZ4"
echo "📱 GREENHOUSE      → Device: GZ1"
echo "📱 DRTPM-Hidroponik → Device: Monitoring_Hidroponik"
echo ""
echo "Total: 5 applications, 11 devices"
echo ""

print_step "3" "WEBHOOK PROCESS FLOW"
echo ""
echo "1️⃣ Sensor (e.g., CZ1) sends data to Antares"
echo "2️⃣ Antares stores data and triggers webhook"
echo "3️⃣ Antares sends POST request to: https://kedairekagreenhouse.my.id/webhook/antares"
echo "4️⃣ Your webhook receives JSON payload like:"
echo '   {
     "m2m:sgn": {
       "nev": {
         "rep": {
           "m2m:cin": {
             "con": "{\"deviceName\":\"CZ1\",\"data\":\"01F402BC006400C8\"}"
           }
         }
       }
     }
   }'
echo "5️⃣ Your webhook extracts: deviceName='CZ1', data='01F402BC006400C8'"
echo "6️⃣ Webhook finds device_id for 'CZ1' in database"
echo "7️⃣ Webhook saves data to sensor_readings table"
echo "8️⃣ Your API endpoints now serve real-time data"
echo ""

print_step "4" "FILES YOU NEED TO CREATE"
echo ""
echo "📁 webhook/ folder structure:"
echo "   webhook/__init__.py          - Package setup"
echo "   webhook/webhook_config.py    - Configuration (device mapping)"
echo "   webhook/webhook_auth.py      - API key authentication"
echo "   webhook/webhook_utils.py     - Data parsing functions" 
echo "   webhook/webhook_handler.py   - Core processing logic"
echo "   webhook/webhook_routes.py    - Flask endpoints"
echo ""
echo "📁 Other files to update:"
echo "   flask_api/app.py            - Add webhook routes"
echo "   .env                        - Add webhook settings"
echo ""

print_step "5" "STEP-BY-STEP IMPLEMENTATION"
echo ""
echo "Let's implement this system step by step..."
echo ""

# Implementation steps
read -p "Continue with implementation? (y/N): " continue_setup
if [[ ! "$continue_setup" =~ ^[Yy]$ ]]; then
    echo "Setup cancelled. Use this guide to implement manually."
    exit 0
fi

echo ""
echo "🔧 IMPLEMENTING WEBHOOK SYSTEM"
echo "=============================="
echo ""

# Create folders
print_info "Creating folder structure..."
cd "$WORK_DIR"
mkdir -p webhook logs
chmod 755 webhook logs
print_success "Created: webhook/ and logs/ directories"
echo ""

# Check if files exist
print_info "Checking webhook files..."
missing_files=()

webhook_files=(
    "webhook/__init__.py"
    "webhook/webhook_config.py"
    "webhook/webhook_auth.py"
    "webhook/webhook_utils.py"
    "webhook/webhook_handler.py"
    "webhook/webhook_routes.py"
)

for file in "${webhook_files[@]}"; do
    if [ ! -f "$file" ]; then
        missing_files+=("$file")
    fi
done

if [ ${#missing_files[@]} -gt 0 ]; then
    print_warning "Missing webhook files. You need to create:"
    for file in "${missing_files[@]}"; do
        echo "   ❌ $file"
    done
    echo ""
    echo "📋 Copy the content from the provided artifacts to create these files."
    echo ""
    read -p "Press Enter after creating all webhook files..."
fi

# Test Python imports
print_info "Testing Python imports..."
cd "$WORK_DIR"
source venv/bin/activate

if python -c "
import sys
sys.path.insert(0, '.')
try:
    from webhook import webhook_handler, register_webhook_routes
    print('✅ All webhook imports successful')
except ImportError as e:
    print(f'❌ Import error: {e}')
    exit(1)
" 2>/dev/null; then
    print_success "Webhook package imports working"
else
    print_warning "Import issues detected - check file contents"
fi

deactivate
echo ""

# Update .env
print_info "Checking .env configuration..."
if ! grep -q "WEBHOOK_RATE_LIMIT" .env; then
    echo "" >> .env
    echo "# Webhook Configuration" >> .env
    echo "WEBHOOK_RATE_LIMIT=1000" >> .env
    echo "WEBHOOK_MAX_PAYLOAD_SIZE=5242880" >> .env
    echo "WEBHOOK_LOG_FILE=/home/elektro1/smart_greenhouse/logs/webhook.log" >> .env
    print_success ".env updated with webhook settings"
else
    print_success ".env already has webhook settings"
fi
echo ""

# Check flask_api/app.py
print_info "Checking Flask app integration..."
if grep -q "register_webhook_routes" flask_api/app.py; then
    print_success "Flask app already integrated with webhooks"
else
    print_warning "flask_api/app.py needs to be updated"
    echo "📋 Update flask_api/app.py with the provided artifact content"
    read -p "Press Enter after updating flask_api/app.py..."
fi
echo ""

# Create systemd service
print_info "Creating systemd service..."
sudo tee /etc/systemd/system/greenhouse-webhook-api.service > /dev/null << EOF
[Unit]
Description=Smart Greenhouse API with Webhook Support
After=network.target postgresql.service

[Service]
Type=simple
User=elektro1
Group=elektro1
WorkingDirectory=$WORK_DIR/flask_api
Environment=PYTHONPATH=$WORK_DIR
ExecStart=$WORK_DIR/venv/bin/python app.py
Restart=always
RestartSec=10
StandardOutput=append:$WORK_DIR/logs/app.log
StandardError=append:$WORK_DIR/logs/error.log

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable greenhouse-webhook-api.service
print_success "Systemd service created and enabled"
echo ""

# Test the system
print_info "Testing webhook system..."
sudo systemctl start greenhouse-webhook-api.service
sleep 5

if systemctl is-active --quiet greenhouse-webhook-api.service; then
    print_success "Webhook API service started successfully"
    
    # Test endpoints
    if curl -s "http://localhost:5000/webhook/test" | grep -q "active"; then
        print_success "Webhook test endpoint working"
    else
        print_warning "Webhook test endpoint issues"
    fi
    
    if curl -s --max-time 10 "https://kedairekagreenhouse.my.id/webhook/test" >/dev/null 2>&1; then
        print_success "External webhook access working"
    else
        print_warning "External webhook access issues (check Cloudflare tunnel)"
    fi
else
    print_warning "Webhook API service failed to start"
    echo "📋 Check logs: journalctl -u greenhouse-webhook-api.service"
fi
echo ""

print_step "6" "ANTARES SUBSCRIBER SETUP"
echo ""
print_info "Now you need to create subscribers in Antares platform..."
echo ""
echo "For each application (CABAI, MELON, SELADA, GREENHOUSE), run:"
echo ""

# Show curl commands with actual API key
API_KEY=$(grep ANTARES_API_KEY .env | cut -d'=' -f2 | head -c 20)
echo "📋 SUBSCRIBER CREATION COMMANDS:"
echo "==============================="
echo ""

for app in CABAI MELON SELADA GREENHOUSE DRTPM-Hidroponik; do
    echo "# Create subscriber for $app:"
    echo "curl -X POST \"https://platform.antares.id:8443/~/antares-cse/antares-id/$app\" \\"
    echo "  -H \"X-M2M-Origin: \$YOUR_ANTARES_API_KEY\" \\"
    echo "  -H \"Content-Type: application/json;ty=23\" \\"
    echo "  -H \"Accept: application/json\" \\"
    echo "  -d '{"
    echo "    \"m2m:sub\": {"
    echo "      \"rn\": \"greenhouse-webhook-$(echo $app | tr '[:upper:]' '[:lower:]' | tr '-' '-')\","
    echo "      \"nu\": \"https://kedairekagreenhouse.my.id/webhook/antares\","
    echo "      \"nct\": 2"
    echo "    }"
    echo "  }'"
    echo ""
done

echo "💡 Replace \$YOUR_ANTARES_API_KEY with your actual API key from .env file"
echo ""

print_step "7" "TESTING AND MONITORING"
echo ""
echo "📊 After setting up subscribers, monitor the system:"
echo ""
echo "# Real-time webhook monitoring:"
echo "tail -f $WORK_DIR/logs/webhook.log"
echo ""
echo "# Check webhook system status:"
echo "curl https://kedairekagreenhouse.my.id/webhook/status"
echo ""
echo "# Monitor database for new data:"
echo "psql -U \$DB_USER -d smart_greenhouse -c \\"
echo "  \"SELECT d.code, sr.encoded_data, sr.timestamp \\"
echo "   FROM sensor_readings sr \\"
echo "   JOIN devices d ON sr.device_id = d.device_id \\"
echo "   WHERE sr.timestamp >= NOW() - INTERVAL '1 hour' \\"
echo "   ORDER BY sr.timestamp DESC LIMIT 10;\""
echo ""

print_step "8" "MIGRATION FROM POLLING"
echo ""
echo "⚠️  IMPORTANT: Keep both systems running initially!"
echo ""
echo "1️⃣ Deploy webhook system (✅ Done above)"
echo "2️⃣ Create Antares subscribers (📋 Do this next)"
echo "3️⃣ Monitor webhook logs for 24-48 hours"
echo "4️⃣ Verify data consistency between both systems"
echo "5️⃣ Once confirmed working, disable polling:"
echo "   sudo systemctl stop greenhouse-fetcher.timer"
echo "   sudo systemctl disable greenhouse-fetcher.timer"
echo ""

echo "🎉 WEBHOOK SETUP COMPLETED!"
echo "=========================="
echo ""
echo "✅ What's implemented:"
echo "   • Webhook API endpoints"
echo "   • Real-time data processing"  
echo "   • Database integration"
echo "   • Error handling and logging"
echo "   • System monitoring"
echo ""
echo "📋 Next steps:"
echo "   1. Create Antares subscribers (commands above)"
echo "   2. Monitor webhook logs: tail -f logs/webhook.log"
echo "   3. Test with real sensor data"
echo "   4. Disable polling once confirmed working"
echo ""
echo "🌐 Your webhook endpoint: https://kedairekagreenhouse.my.id/webhook/antares"
echo "🔑 Authentication: X-API-KEY header (from your .env file)"
echo ""
print_success "Your system is ready for real-time data collection!"