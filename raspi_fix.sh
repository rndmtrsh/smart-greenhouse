#!/bin/bash
# ========================
# Raspberry Pi Diagnostic & Resource Management
# Fix untuk masalah SSH crash dan system stability
# ========================

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_header() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE} $1 ${NC}"
    echo -e "${BLUE}========================================${NC}"
}

print_status() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_info() {
    echo -e "${BLUE}[i]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

# ========================
# SYSTEM DIAGNOSTIC
# ========================
system_diagnostic() {
    print_header "RASPBERRY PI SYSTEM DIAGNOSTIC"
    
    echo "🖥️ System Information:"
    echo "======================"
    
    # Basic system info
    echo "Hostname: $(hostname)"
    echo "Uptime: $(uptime -p)"
    echo "Kernel: $(uname -r)"
    
    # Memory info
    echo ""
    echo "💾 Memory Status:"
    echo "=================="
    free -h
    
    # Temperature
    echo ""
    echo "🌡️ CPU Temperature:"
    echo "==================="
    if [ -f "/sys/class/thermal/thermal_zone0/temp" ]; then
        temp_raw=$(cat /sys/class/thermal/thermal_zone0/temp)
        temp_c=$((temp_raw / 1000))
        echo "Current: ${temp_c}°C"
        
        if [ "$temp_c" -gt 80 ]; then
            print_error "⚠️ CRITICAL: CPU overheating! (${temp_c}°C)"
        elif [ "$temp_c" -gt 70 ]; then
            print_warning "⚠️ WARNING: CPU running hot (${temp_c}°C)"
        else
            print_status "CPU temperature normal (${temp_c}°C)"
        fi
    fi
    
    # Disk usage
    echo ""
    echo "💿 Disk Usage:"
    echo "=============="
    df -h / /boot
    
    # Check swap usage
    echo ""
    echo "🔄 Swap Usage:"
    echo "=============="
    swapon --show
    echo "Swap usage: $(free | grep Swap | awk '{printf "%.1f%%", $3/$2 * 100}')"
    
    # Load average
    echo ""
    echo "⚡ System Load:"
    echo "==============="
    echo "Load Average: $(uptime | awk -F'load average:' '{print $2}')"
    
    # Top memory consumers
    echo ""
    echo "🔝 Top Memory Consumers:"
    echo "========================"
    ps aux --sort=-%mem | head -6
    
    # Check for memory leaks in our services
    echo ""
    echo "🔍 Greenhouse Services Memory Usage:"
    echo "==================================="
    ps aux | grep -E "(fetch_antares|greenhouse|python.*venv)" | grep -v grep || echo "No greenhouse processes running"
}

# ========================
# CHECK POTENTIAL ISSUES
# ========================
check_issues() {
    print_header "POTENTIAL ISSUE ANALYSIS"
    
    issues_found=0
    
    # 1. Memory usage check
    memory_usage=$(free | grep Mem: | awk '{printf "%.0f", $3/$2 * 100}')
    if [ "$memory_usage" -gt 90 ]; then
        print_error "🚨 HIGH MEMORY USAGE: ${memory_usage}%"
        echo "   This can cause SSH to become unresponsive"
        issues_found=$((issues_found + 1))
    elif [ "$memory_usage" -gt 80 ]; then
        print_warning "⚠️ ELEVATED MEMORY USAGE: ${memory_usage}%"
        issues_found=$((issues_found + 1))
    else
        print_status "Memory usage OK: ${memory_usage}%"
    fi
    
    # 2. Swap usage check
    swap_total=$(free | grep Swap | awk '{print $2}')
    if [ "$swap_total" -eq 0 ]; then
        print_warning "⚠️ NO SWAP FILE CONFIGURED"
        echo "   This can cause system instability under memory pressure"
        issues_found=$((issues_found + 1))
    else
        swap_usage=$(free | grep Swap | awk '{if($2>0) printf "%.0f", $3/$2 * 100; else print "0"}')
        if [ "$swap_usage" -gt 50 ]; then
            print_warning "⚠️ HIGH SWAP USAGE: ${swap_usage}%"
            issues_found=$((issues_found + 1))
        fi
    fi
    
    # 3. Temperature check
    if [ -f "/sys/class/thermal/thermal_zone0/temp" ]; then
        temp_raw=$(cat /sys/class/thermal/thermal_zone0/temp)
        temp_c=$((temp_raw / 1000))
        if [ "$temp_c" -gt 75 ]; then
            print_error "🚨 HIGH TEMPERATURE: ${temp_c}°C"
            echo "   Heat can cause system instability and crashes"
            issues_found=$((issues_found + 1))
        fi
    fi
    
    # 4. Disk space check
    disk_usage=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
    if [ "$disk_usage" -gt 95 ]; then
        print_error "🚨 DISK ALMOST FULL: ${disk_usage}%"
        echo "   Low disk space can cause system crashes"
        issues_found=$((issues_found + 1))
    elif [ "$disk_usage" -gt 85 ]; then
        print_warning "⚠️ LOW DISK SPACE: ${disk_usage}%"
        issues_found=$((issues_found + 1))
    fi
    
    # 5. Check for memory leaks in our services
    python_processes=$(ps aux | grep -E "python.*venv.*fetch" | wc -l)
    if [ "$python_processes" -gt 3 ]; then
        print_warning "⚠️ MULTIPLE PYTHON PROCESSES DETECTED: $python_processes"
        echo "   This might indicate process accumulation"
        issues_found=$((issues_found + 1))
    fi
    
    # 6. Check systemd journal size
    journal_size=$(du -sh /var/log/journal 2>/dev/null | cut -f1 || echo "0")
    if [[ "$journal_size" =~ ^[0-9]+[GM]$ ]]; then
        size_num=$(echo "$journal_size" | sed 's/[GM]//')
        size_unit=$(echo "$journal_size" | sed 's/[0-9]*//')
        if [ "$size_unit" = "G" ] && [ "$size_num" -gt 1 ]; then
            print_warning "⚠️ LARGE SYSTEMD JOURNAL: $journal_size"
            issues_found=$((issues_found + 1))
        fi
    fi
    
    # 7. Check for runaway cron jobs
    cron_processes=$(ps aux | grep cron | grep -v grep | wc -l)
    if [ "$cron_processes" -gt 5 ]; then
        print_warning "⚠️ MANY CRON PROCESSES: $cron_processes"
        issues_found=$((issues_found + 1))
    fi
    
    # Summary
    echo ""
    if [ "$issues_found" -eq 0 ]; then
        print_status "✅ No critical issues detected"
    else
        print_error "🚨 Found $issues_found potential issues that may cause SSH crashes"
    fi
}

# ========================
# RESOURCE OPTIMIZATION
# ========================
optimize_resources() {
    print_header "RESOURCE OPTIMIZATION"
    
    print_info "Applying resource optimizations..."
    
    # 1. Create/increase swap file if needed
    if ! swapon --show | grep -q "/"; then
        print_info "Creating swap file..."
        sudo fallocate -l 1G /swapfile
        sudo chmod 600 /swapfile
        sudo mkswap /swapfile
        sudo swapon /swapfile
        echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
        print_status "1GB swap file created"
    fi
    
    # 2. Optimize memory settings
    print_info "Optimizing memory settings..."
    
    # Set swappiness to prefer RAM over swap
    echo 'vm.swappiness=10' | sudo tee -a /etc/sysctl.conf
    
    # Optimize dirty page handling
    echo 'vm.dirty_ratio=15' | sudo tee -a /etc/sysctl.conf
    echo 'vm.dirty_background_ratio=5' | sudo tee -a /etc/sysctl.conf
    
    # Apply immediately
    sudo sysctl vm.swappiness=10
    sudo sysctl vm.dirty_ratio=15
    sudo sysctl vm.dirty_background_ratio=5
    
    print_status "Memory settings optimized"
    
    # 3. Optimize systemd journal
    print_info "Limiting systemd journal size..."
    sudo mkdir -p /etc/systemd/journald.conf.d/
    cat << EOF | sudo tee /etc/systemd/journald.conf.d/00-journal-size.conf
[Journal]
SystemMaxUse=100M
SystemMaxFileSize=10M
MaxRetentionSec=7day
ForwardToSyslog=no
EOF
    sudo systemctl restart systemd-journald
    print_status "Journal size limited to 100MB"
    
    # 4. Clean up system
    print_info "Cleaning up system..."
    sudo apt-get autoremove -y
    sudo apt-get autoclean
    sudo journalctl --vacuum-time=7d
    print_status "System cleanup completed"
}

# ========================
# FIX AUTOMATION SERVICES
# ========================
fix_automation_services() {
    print_header "FIXING AUTOMATION SERVICES"
    
    # 1. Add resource limits to systemd services
    print_info "Adding resource limits to services..."
    
    # Update greenhouse-fetcher service with strict limits
    sudo tee /etc/systemd/system/greenhouse-fetcher.service > /dev/null << 'EOF'
[Unit]
Description=Smart Greenhouse Data Fetcher
After=network.target postgresql.service
Wants=postgresql.service

[Service]
Type=oneshot
User=elektro1
Group=elektro1
WorkingDirectory=/home/elektro1/smart_greenhouse
Environment=PYTHONPATH=/home/elektro1/smart_greenhouse
ExecStart=/home/elektro1/smart_greenhouse/venv/bin/python /home/elektro1/smart_greenhouse/fetch_antares/fetch_antares.py
StandardOutput=append:/home/elektro1/smart_greenhouse/middleware.log
StandardError=append:/home/elektro1/smart_greenhouse/middleware.log
TimeoutSec=60
Restart=no

# Strict resource limits
MemoryMax=256M
MemoryHigh=200M
CPUQuota=25%
TasksMax=10
PrivateTmp=yes
ProtectSystem=strict
ReadWritePaths=/home/elektro1/smart_greenhouse
NoNewPrivileges=yes
EOF
    
    # Update daemon service with limits
    if [ -f "/etc/systemd/system/greenhouse-daemon.service" ]; then
        sudo tee /etc/systemd/system/greenhouse-daemon.service > /dev/null << 'EOF'
[Unit]
Description=Smart Greenhouse Data Fetcher Daemon
After=network.target postgresql.service
Wants=postgresql.service

[Service]
Type=simple
User=elektro1
Group=elektro1
WorkingDirectory=/home/elektro1/smart_greenhouse
ExecStart=/home/elektro1/smart_greenhouse/venv/bin/python /home/elektro1/smart_greenhouse/fetch_daemon.py
Restart=always
RestartSec=30
PIDFile=/home/elektro1/smart_greenhouse/fetcher.pid
TimeoutStopSec=10

# Strict resource limits
MemoryMax=256M
MemoryHigh=200M
CPUQuota=30%
TasksMax=15
PrivateTmp=yes
ProtectSystem=strict
ReadWritePaths=/home/elektro1/smart_greenhouse
NoNewPrivileges=yes

[Install]
WantedBy=multi-user.target
EOF
    fi
    
    sudo systemctl daemon-reload
    print_status "Service resource limits applied"
    
    # 2. Optimize cron wrapper script
    print_info "Optimizing cron wrapper script..."
    
    cat > /home/elektro1/smart_greenhouse/run_fetcher.sh << 'EOF'
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
EOF

    chmod +x /home/elektro1/smart_greenhouse/run_fetcher.sh
    print_status "Cron wrapper script optimized"
    
    # 3. Update maintenance script with memory checks
    print_info "Adding memory monitoring to maintenance script..."
    
    # Add memory check to maintenance script
    cat >> /home/elektro1/smart_greenhouse/maintenance/greenhouse_maintenance.sh << 'EOF'

# Memory usage check before maintenance
check_memory_usage() {
    available_mem=$(free -m | awk 'NR==2{printf "%.0f", $7}')
    if [ "$available_mem" -lt 200 ]; then
        log_message "WARNING: Low available memory ($available_mem MB)"
        # Skip heavy operations if memory is low
        return 1
    fi
    return 0
}
EOF
    
    print_status "Memory monitoring added to maintenance"
}

# ========================
# SSH OPTIMIZATION
# ========================
optimize_ssh() {
    print_header "SSH OPTIMIZATION"
    
    print_info "Optimizing SSH configuration..."
    
    # Backup original sshd_config
    sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup.$(date +%Y%m%d)
    
    # Optimize SSH settings
    sudo tee -a /etc/ssh/sshd_config > /dev/null << 'EOF'

# Smart Greenhouse SSH Optimizations
ClientAliveInterval 60
ClientAliveCountMax 10
MaxStartups 10:30:60
LoginGraceTime 60
MaxSessions 5
TCPKeepAlive yes
Compression yes
EOF
    
    # Restart SSH service
    sudo systemctl restart ssh
    print_status "SSH service optimized and restarted"
    
    # Enable SSH service monitoring
    sudo systemctl enable ssh
    print_status "SSH service monitoring enabled"
}

# ========================
# CREATE MONITORING SCRIPT
# ========================
create_monitoring_script() {
    print_header "CREATING SYSTEM MONITORING"
    
    cat > /home/elektro1/smart_greenhouse/system_monitor.sh << 'EOF'
#!/bin/bash
# System Health Monitor for Raspberry Pi

LOG_FILE="/home/elektro1/smart_greenhouse/system_health.log"

log_health() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# Check memory usage
memory_usage=$(free | grep Mem: | awk '{printf "%.0f", $3/$2 * 100}')
if [ "$memory_usage" -gt 85 ]; then
    log_health "WARNING: High memory usage: ${memory_usage}%"
    # Kill any stuck processes
    pkill -f "fetch_antares.py" 2>/dev/null || true
fi

# Check temperature
if [ -f "/sys/class/thermal/thermal_zone0/temp" ]; then
    temp_raw=$(cat /sys/class/thermal/thermal_zone0/temp)
    temp_c=$((temp_raw / 1000))
    if [ "$temp_c" -gt 75 ]; then
        log_health "WARNING: High temperature: ${temp_c}°C"
    fi
fi

# Check disk space
disk_usage=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
if [ "$disk_usage" -gt 90 ]; then
    log_health "WARNING: Low disk space: ${disk_usage}%"
fi

# Check for stuck processes
stuck_processes=$(ps aux | grep -E "fetch_antares|greenhouse" | grep -v grep | wc -l)
if [ "$stuck_processes" -gt 5 ]; then
    log_health "WARNING: Too many processes: $stuck_processes"
fi

# Check SSH service
if ! systemctl is-active --quiet ssh; then
    log_health "CRITICAL: SSH service down"
    sudo systemctl restart ssh
fi
EOF

    chmod +x /home/elektro1/smart_greenhouse/system_monitor.sh
    
    # Add to crontab - run every 5 minutes
    (crontab -l 2>/dev/null | grep -v "system_monitor.sh"; echo "*/5 * * * * /home/elektro1/smart_greenhouse/system_monitor.sh") | crontab -
    
    print_status "System monitoring script created and scheduled"
}

# ========================
# MAIN MENU
# ========================
main() {
    print_header "RASPBERRY PI STABILITY FIXER"
    
    echo "🔧 Select action:"
    echo "1) Full diagnostic + analysis"
    echo "2) Apply all fixes (recommended)"
    echo "3) Resource optimization only"
    echo "4) SSH optimization only"
    echo "5) Fix automation services only"
    echo "6) Create monitoring only"
    echo "7) Emergency cleanup"
    echo ""
    read -p "Choice (1-7): " choice
    
    case "$choice" in
        1)
            system_diagnostic
            check_issues
            ;;
        2)
            system_diagnostic
            check_issues
            optimize_resources
            fix_automation_services
            optimize_ssh
            create_monitoring_script
            
            print_header "ALL FIXES APPLIED!"
            echo "✅ System optimized for stability"
            echo "✅ Resource limits applied"
            echo "✅ SSH optimized"
            echo "✅ Monitoring enabled"
            echo ""
            echo "🔄 Recommended: Restart system to apply all changes"
            read -p "Restart now? (y/N): " restart
            if [[ "$restart" =~ ^[Yy]$ ]]; then
                sudo reboot
            fi
            ;;
        3)
            optimize_resources
            ;;
        4)
            optimize_ssh
            ;;
        5)
            fix_automation_services
            ;;
        6)
            create_monitoring_script
            ;;
        7)
            print_info "Running emergency cleanup..."
            sudo pkill -f "fetch_antares.py" 2>/dev/null || true
            sudo pkill -f "greenhouse" 2>/dev/null || true
            rm -f /tmp/greenhouse_fetch.lock
            sudo systemctl restart ssh
            sudo systemctl restart greenhouse-fetcher.timer
            free && sync && echo 3 | sudo tee /proc/sys/vm/drop_caches
            print_status "Emergency cleanup completed"
            ;;
        *)
            print_error "Invalid choice"
            exit 1
            ;;
    esac
}

main "$@"