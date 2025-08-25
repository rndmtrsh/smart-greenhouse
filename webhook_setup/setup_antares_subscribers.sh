#!/bin/bash
# ========================
# Antares Subscriber Setup Commands
# Create webhooks for each application
# ========================

# Your Antares API Key (from .env file)
ANTARES_API_KEY=$(grep ANTARES_API_KEY /home/elektro1/smart_greenhouse/.env | cut -d'=' -f2)

# Your webhook endpoint
WEBHOOK_URL="https://kedairekagreenhouse.my.id/webhook/antares"

echo "🌱 Setting up Antares Subscribers for Webhook"
echo "=============================================="
echo ""

# 1. Create Subscriber for CABAI Application
echo "1. Creating subscriber for CABAI application..."
curl -X POST "https://platform.antares.id:8443/~/antares-cse/antares-id/CABAI" \
  -H "X-M2M-Origin: $ANTARES_API_KEY" \
  -H "Content-Type: application/json;ty=23" \
  -H "Accept: application/json" \
  -d '{
    "m2m:sub": {
      "rn": "greenhouse-webhook-cabai",
      "nu": "'$WEBHOOK_URL'",
      "nct": 2
    }
  }'
echo ""
echo "✅ CABAI subscriber created"
echo ""

# 2. Create Subscriber for MELON Application  
echo "2. Creating subscriber for MELON application..."
curl -X POST "https://platform.antares.id:8443/~/antares-cse/antares-id/MELON" \
  -H "X-M2M-Origin: $ANTARES_API_KEY" \
  -H "Content-Type: application/json;ty=23" \
  -H "Accept: application/json" \
  -d '{
    "m2m:sub": {
      "rn": "greenhouse-webhook-melon",
      "nu": "'$WEBHOOK_URL'",
      "nct": 2
    }
  }'
echo ""
echo "✅ MELON subscriber created"
echo ""

# 3. Create Subscriber for SELADA Application
echo "3. Creating subscriber for SELADA application..."
curl -X POST "https://platform.antares.id:8443/~/antares-cse/antares-id/SELADA" \
  -H "X-M2M-Origin: $ANTARES_API_KEY" \
  -H "Content-Type: application/json;ty=23" \
  -H "Accept: application/json" \
  -d '{
    "m2m:sub": {
      "rn": "greenhouse-webhook-selada",
      "nu": "'$WEBHOOK_URL'",
      "nct": 2
    }
  }'
echo ""
echo "✅ SELADA subscriber created"
echo ""

# 4. Create Subscriber for GREENHOUSE Application
echo "4. Creating subscriber for GREENHOUSE application..."
curl -X POST "https://platform.antares.id:8443/~/antares-cse/antares-id/GREENHOUSE" \
  -H "X-M2M-Origin: $ANTARES_API_KEY" \
  -H "Content-Type: application/json;ty=23" \
  -H "Accept: application/json" \
  -d '{
    "m2m:sub": {
      "rn": "greenhouse-webhook-greenhouse", 
      "nu": "'$WEBHOOK_URL'",
      "nct": 2
    }
  }'
echo ""
echo "✅ GREENHOUSE subscriber created"
echo ""

# 5. Create Subscriber for DRTPM-Hidroponik Application
echo "5. Creating subscriber for DRTPM-Hidroponik application..."
curl -X POST "https://platform.antares.id:8443/~/antares-cse/antares-id/DRTPM-Hidroponik" \
  -H "X-M2M-Origin: $ANTARES_API_KEY" \
  -H "Content-Type: application/json;ty=23" \
  -H "Accept: application/json" \
  -d '{
    "m2m:sub": {
      "rn": "greenhouse-webhook-drtpm-hidroponik",
      "nu": "'$WEBHOOK_URL'",
      "nct": 2
    }
  }'
echo ""
echo "✅ DRTPM-Hidroponik subscriber created"
echo ""

echo "🎉 All subscribers created successfully!"
echo ""
echo "📋 Summary:"
echo "==========="
echo "✅ CABAI           → greenhouse-webhook-cabai"
echo "✅ MELON           → greenhouse-webhook-melon" 
echo "✅ SELADA          → greenhouse-webhook-selada"
echo "✅ GREENHOUSE      → greenhouse-webhook-greenhouse"
echo "✅ DRTPM-Hidroponik → greenhouse-webhook-drtpm-hidroponik"
echo ""
echo "Webhook URL: $WEBHOOK_URL"
echo ""
echo "🔍 To verify subscribers were created:"
echo "======================================"
echo ""
echo "# Check CABAI subscribers"
echo 'curl -X GET "https://platform.antares.id:8443/~/antares-cse/antares-id/CABAI?fu=1&ty=23" \'
echo '  -H "X-M2M-Origin: '$ANTARES_API_KEY'" \'
echo '  -H "Accept: application/json"'
echo ""
echo "# Check MELON subscribers" 
echo 'curl -X GET "https://platform.antares.id:8443/~/antares-cse/antares-id/MELON?fu=1&ty=23" \'
echo '  -H "X-M2M-Origin: '$ANTARES_API_KEY'" \'
echo '  -H "Accept: application/json"'
echo ""
echo "# Check SELADA subscribers"
echo 'curl -X GET "https://platform.antares.id:8443/~/antares-cse/antares-id/SELADA?fu=1&ty=23" \'
echo '  -H "X-M2M-Origin: '$ANTARES_API_KEY'" \'
echo '  -H "Accept: application/json"'
echo ""
echo "# Check GREENHOUSE subscribers"
echo 'curl -X GET "https://platform.antares.id:8443/~/antares-cse/antares-id/GREENHOUSE?fu=1&ty=23" \'
echo '  -H "X-M2M-Origin: '$ANTARES_API_KEY'" \'
echo '  -H "Accept: application/json"'