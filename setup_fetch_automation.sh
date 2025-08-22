#!/bin/bash
# ========================
# Setup Otomasi untuk fetch_antares.py dengan Virtual Environment
# Mengambil data setiap 5 menit secara otomatis
# ========================

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Configuration
WORK_DIR="/home/elektro1/smart_greenhouse"
VENV_DIR="$WORK_DIR/venv"
FETCH_SCRIPT="$WORK_DIR/fetch_antares/fetch_antares.py"
LOG_FILE="$WORK_DIR/middleware.log"
SERVICE_NAME="greenhouse-fetcher"

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

print_header() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE} $1 ${NC}"
    echo -e "${BLUE}========================================${NC}\n"
}

# ========================
# CHECK AND SETUP VIRTUAL ENVIRONMENT
# ========================
setup_virtual_environment() {
    print_header "CHECKING VIRTUAL ENVIRONMENT"
    
    if [ ! -d "$VENV_DIR" ]; then
        print_info "Creating virtual environment..."
        python3 -m venv "$VENV_DIR"
        print_status "Virtual environment created: $VENV_DIR"
    else
        print_status "Virtual environment exists: $VENV_DIR"
    fi
    
    # Install required packages
    print_info "Installing required packages in virtual environment..."
    source "$VENV_DIR/bin/activate"
    pip install --upgrade pip
    pip install psycopg2-binary python-dotenv requests
    deactivate
    print_status "Required packages installed"
}

# ========================
# METHOD 1: SYSTEMD SERVICE (RECOMMENDED)
# ========================
create_systemd_service() {
    print_header "CREATING SYSTEMD SERVICE"
    
    # Create systemd service file
    sudo tee /etc/systemd/system/${SERVICE_NAME}.service > /dev/null << EOF
[Unit]
Description=Smart Greenhouse Data Fetcher
After=network.target postgresql.service
Wants=postgresql.service

[Service]
Type=oneshot
User=elektro1
Group=elektro1
WorkingDirectory=$WORK_DIR
Environment=PYTHONPATH=$WORK_DIR
ExecStart=$VENV_DIR/bin/python $FETCH_SCRIPT
StandardOutput=append:$LOG_FILE
StandardError=append:$LOG_FILE

# Resource limits
MemoryMax=512M
CPUQuota=50%
EOF

    print_status "Systemd service created: /etc/systemd/system/${SERVICE_NAME}.service"
}

create_systemd_timer() {
    print_header "CREATING SYSTEMD TIMER"
    
    # Create systemd timer file  
    sudo tee /etc/systemd/system/${SERVICE_NAME}.timer > /dev/null << EOF
[Unit]
Description=Run Smart Greenhouse Data Fetcher every 5 minutes
Requires=${SERVICE_NAME}.service

[Timer]
OnBootSec=1min
OnUnitActiveSec=5min
AccuracySec=1s

[Install]
WantedBy=timers.target
EOF

    print_status "Systemd timer created: /etc/systemd/system/${SERVICE_NAME}.timer"
}

# ========================
# METHOD 2: CRON JOB (ALTERNATIVE)
# ========================
setup_cron_job() {
    print_header "SETTING UP CRON JOB (ALTERNATIVE METHOD)"
    
    # Create wrapper script for cron
    cat > "$WORK_DIR/run_fetcher.sh" << EOF
#!/bin/bash
# Wrapper script for cron job with virtual environment

cd $WORK_DIR

# Activate virtual environment
source $VENV_DIR/bin/activate

# Set environment variables
export PYTHONPATH=$WORK_DIR

# Log timestamp
echo "\$(date '+%Y-%m-%d %H:%M:%S') - Starting data fetch..." >> $LOG_FILE

# Run fetch script
python $FETCH_SCRIPT >> $LOG_FILE 2>&1

# Log completion
echo "\$(date '+%Y-%m-%d %H:%M:%S') - Data fetch completed" >> $LOG_FILE

# Deactivate virtual environment
deactivate
EOF

    chmod +x "$WORK_DIR/run_fetcher.sh"
    print_status "Wrapper script created: $WORK_DIR/run_fetcher.sh"
    
    # Add to crontab
    (crontab -l 2>/dev/null | grep -v "run_fetcher.sh"; echo "*/5 * * * * $WORK_DIR/run_fetcher.sh") | crontab -
    print_status "Cron job added: Every 5 minutes"
}

# ========================
# METHOD 3: PYTHON DAEMON (ADVANCED)
# ========================
create_python_daemon() {
    print_header "CREATING PYTHON DAEMON SCRIPT"
    
    cat > "$WORK_DIR/fetch_daemon.py" << 'EOF'
#!/usr/bin/env python3
"""
Smart Greenhouse Data Fetcher Daemon
Runs continuously and fetches data every 5 minutes
"""

import time
import sys
import os
import signal
import logging
from datetime import datetime
from pathlib import Path

# Add project directory to Python path
WORK_DIR = Path("/home/elektro1/smart_greenhouse")
sys.path.insert(0, str(WORK_DIR))

# Import the fetch module
from fetch_antares.fetch_antares import run_middleware

# Configuration
LOG_FILE = WORK_DIR / "middleware.log"
PID_FILE = WORK_DIR / "fetcher.pid"
FETCH_INTERVAL = 300  # 5 minutes in seconds

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s',
    handlers=[
        logging.FileHandler(LOG_FILE),
        logging.StreamHandler(sys.stdout)
    ]
)

logger = logging.getLogger(__name__)

class DataFetcherDaemon:
    def __init__(self):
        self.running = True
        self.setup_signal_handlers()
    
    def setup_signal_handlers(self):
        """Setup signal handlers for graceful shutdown"""
        signal.signal(signal.SIGTERM, self.signal_handler)
        signal.signal(signal.SIGINT, self.signal_handler)
    
    def signal_handler(self, signum, frame):
        """Handle shutdown signals"""
        logger.info(f"Received signal {signum}, shutting down gracefully...")
        self.running = False
    
    def write_pid_file(self):
        """Write process ID to file"""
        with open(PID_FILE, 'w') as f:
            f.write(str(os.getpid()))
        logger.info(f"PID file created: {PID_FILE}")
    
    def remove_pid_file(self):
        """Remove PID file"""
        if PID_FILE.exists():
            PID_FILE.unlink()
            logger.info("PID file removed")
    
    def fetch_data(self):
        """Fetch data from Antares"""
        try:
            logger.info("Starting data fetch from Antares...")
            run_middleware()
            logger.info("Data fetch completed successfully")
        except Exception as e:
            logger.error(f"Error during data fetch: {e}")
    
    def run(self):
        """Main daemon loop"""
        logger.info("Smart Greenhouse Data Fetcher Daemon started")
        logger.info(f"Fetch interval: {FETCH_INTERVAL} seconds (5 minutes)")
        
        self.write_pid_file()
        
        try:
            while self.running:
                self.fetch_data()
                
                # Sleep for 5 minutes, but check for shutdown every second
                for _ in range(FETCH_INTERVAL):
                    if not self.running:
                        break
                    time.sleep(1)
                    
        except Exception as e:
            logger.error(f"Daemon error: {e}")
        finally:
            self.remove_pid_file()
            logger.info("Data Fetcher Daemon stopped")

if __name__ == "__main__":
    daemon = DataFetcherDaemon()
    daemon.run()
EOF

    chmod +x "$WORK_DIR/fetch_daemon.py"
    print_status "Python daemon created: $WORK_DIR/fetch_daemon.py"
    
    # Create systemd service for Python daemon
    sudo tee /etc/systemd/system/greenhouse-daemon.service > /dev/null << EOF
[Unit]
Description=Smart Greenhouse Data Fetcher Daemon
After=network.target postgresql.service
Wants=postgresql.service

[Service]
Type=simple
User=elektro1
Group=elektro1
WorkingDirectory=$WORK_DIR
ExecStart=$VENV_DIR/bin/python $WORK_DIR/fetch_daemon.py
Restart=always
RestartSec=10
PIDFile=$WORK_DIR/fetcher.pid

# Resource limits
MemoryMax=512M
CPUQuota=30%

[Install]
WantedBy=multi-user.target
EOF

    print_status "Daemon systemd service created"
}

# ========================
# SETUP LOG ROTATION
# ========================
setup_log_rotation() {
    print_header "SETTING UP LOG ROTATION"
    
    # Add middleware.log to logrotate
    if ! grep -q "$LOG_FILE" /etc/logrotate.d/greenhouse 2>/dev/null; then
        sudo tee -a /etc/logrotate.d/greenhouse > /dev/null << EOF

$LOG_FILE {
    daily
    missingok
    rotate 7
    compress
    delaycompress
    notifempty
    create 644 elektro1 elektro1
    maxsize 100M
    postrotate
        # Send HUP signal to restart logging if using daemon mode
        if [ -f $WORK_DIR/fetcher.pid ]; then
            kill -HUP \$(cat $WORK_DIR/fetcher.pid) 2>/dev/null || true
        fi
    endscript
}
EOF
        print_status "Log rotation added for middleware.log"
    else
        print_info "Log rotation already configured"
    fi
}

# ========================
# CREATE TEST SCRIPT
# ========================
create_test_script() {
    print_header "CREATING TEST SCRIPT"
    
    cat > "$WORK_DIR/test_fetch.sh" << EOF
#!/bin/bash
# Test script untuk manual testing dengan virtual environment

cd $WORK_DIR

echo "Testing fetch_antares.py with virtual environment..."
echo "=============================================="

# Activate virtual environment
source $VENV_DIR/bin/activate

# Check Python and packages
echo "Python version: \$(python --version)"
echo "Virtual environment: $VENV_DIR"

# Set environment variables
export PYTHONPATH=$WORK_DIR

# Run test
echo ""
echo "Running fetch_antares.py..."
echo "Log output:"
python $FETCH_SCRIPT

# Deactivate virtual environment
deactivate

echo ""
echo "Test completed. Check $LOG_FILE for detailed logs."
EOF

    chmod +x "$WORK_DIR/test_fetch.sh"
    print_status "Test script created: $WORK_DIR/test_fetch.sh"
}

# ========================
# MAIN INSTALLATION MENU
# ========================
main() {
    print_header "SMART GREENHOUSE FETCH AUTOMATION SETUP (WITH VENV)"
    
    # Check prerequisites
    if [ ! -f "$FETCH_SCRIPT" ]; then
        print_error "fetch_antares.py not found at $FETCH_SCRIPT"
        exit 1
    fi
    
    if [ "$USER" != "elektro1" ]; then
        print_warning "Should be run as elektro1 user"
    fi
    
    # Setup virtual environment first
    setup_virtual_environment
    
    # Create log file
    touch "$LOG_FILE"
    print_status "Log file ready: $LOG_FILE"
    
    # Create test script
    create_test_script
    
    echo "Choose automation method:"
    echo "1) Systemd Timer (Recommended) - Most reliable"
    echo "2) Cron Job - Simple and traditional"  
    echo "3) Python Daemon - Continuous running"
    echo "4) Setup All Methods"
    echo "5) Test Only - Create test script and exit"
    echo ""
    read -p "Select option (1-5): " choice
    
    case $choice in
        1)
            print_info "Setting up Systemd Timer method..."
            create_systemd_service
            create_systemd_timer
            setup_log_rotation
            
            # Enable and start services
            sudo systemctl daemon-reload
            sudo systemctl enable ${SERVICE_NAME}.timer
            sudo systemctl start ${SERVICE_NAME}.timer
            
            print_status "Systemd timer method setup complete!"
            print_info "Status: sudo systemctl status ${SERVICE_NAME}.timer"
            ;;
            
        2)
            print_info "Setting up Cron Job method..."
            setup_cron_job
            setup_log_rotation
            
            print_status "Cron job method setup complete!"
            print_info "Check: crontab -l | grep run_fetcher"
            ;;
            
        3)
            print_info "Setting up Python Daemon method..."
            create_python_daemon
            setup_log_rotation
            
            # Enable and start daemon service
            sudo systemctl daemon-reload
            sudo systemctl enable greenhouse-daemon.service
            sudo systemctl start greenhouse-daemon.service
            
            print_status "Python daemon method setup complete!"
            print_info "Status: sudo systemctl status greenhouse-daemon"
            ;;
            
        4)
            print_info "Setting up ALL methods..."
            create_systemd_service
            create_systemd_timer  
            setup_cron_job
            create_python_daemon
            setup_log_rotation
            
            print_status "All methods created! Choose one to activate:"
            print_info "Systemd Timer: sudo systemctl enable --now ${SERVICE_NAME}.timer"
            print_info "Python Daemon: sudo systemctl enable --now greenhouse-daemon"
            print_info "Cron Job: Already active"
            ;;
            
        5)
            print_info "Test setup complete. Run: $WORK_DIR/test_fetch.sh"
            exit 0
            ;;
            
        *)
            print_error "Invalid choice"
            exit 1
            ;;
    esac
    
    # Final instructions
    echo ""
    print_header "SETUP COMPLETED!"
    
    echo -e "${GREEN}✅ Automation Status:${NC}"
    echo "   📄 Fetch script: $FETCH_SCRIPT"
    echo "   🐍 Virtual environment: $VENV_DIR"
    echo "   📋 Log file: $LOG_FILE"
    echo "   ⏰ Interval: Every 5 minutes"
    echo ""
    
    echo -e "${BLUE}📋 Testing Commands:${NC}"
    echo "   # Test manual run with venv"
    echo "   $WORK_DIR/test_fetch.sh"
    echo ""
    echo "   # Test virtual environment"
    echo "   source $VENV_DIR/bin/activate && python --version && deactivate"
    echo ""
    
    echo -e "${BLUE}📋 Monitoring Commands:${NC}"
    echo "   # View real-time logs"
    echo "   tail -f $LOG_FILE"
    echo ""
    echo "   # Check systemd timer status"
    echo "   sudo systemctl status ${SERVICE_NAME}.timer"
    echo "   sudo systemctl list-timers | grep greenhouse"
    echo ""
    echo "   # Check cron job"
    echo "   crontab -l | grep run_fetcher"
    echo ""
    echo "   # Check daemon status"
    echo "   sudo systemctl status greenhouse-daemon"
    echo ""
    
    echo -e "${YELLOW}⚙️ Control Commands:${NC}"
    echo "   # Stop/Start systemd timer"
    echo "   sudo systemctl stop ${SERVICE_NAME}.timer"
    echo "   sudo systemctl start ${SERVICE_NAME}.timer"
    echo ""
    echo "   # Manual run with virtual environment"
    echo "   cd $WORK_DIR && source $VENV_DIR/bin/activate && python $FETCH_SCRIPT && deactivate"
    echo ""
    echo "   # Check processes"
    echo "   ps aux | grep -E \"(fetch_antares|run_fetcher)\" | grep -v grep"
    echo ""
    
    echo -e "${GREEN}🔍 Troubleshooting:${NC}"
    echo "   # Test virtual environment packages"
    echo "   source $VENV_DIR/bin/activate && pip list | grep -E \"(psycopg2|requests|python-dotenv)\""
    echo ""
    echo "   # Check systemd logs"
    echo "   sudo journalctl -u ${SERVICE_NAME}.service -f"
    echo ""
    echo "   # Check cron logs"
    echo "   grep CRON /var/log/syslog | tail -5"
    echo ""
    
    print_status "Data fetching will start automatically every 5 minutes using virtual environment!"
    
    # Offer to run test
    echo ""
    read -p "Run test now to verify setup? (y/N): " test_choice
    if [[ "$test_choice" =~ ^[Yy]$ ]]; then
        print_info "Running test..."
        "$WORK_DIR/test_fetch.sh"
    fi
}

# Run main function
main "$@"