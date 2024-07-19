#!/bin/bash

#################################################################################
# Script Name: Hibernation Management Script
# Description: This script automates the management of hibernation attempts
#              on Ubuntu/Pop!_OS systems by analyzing and handling potential
#              process-related blocks to hibernation. If hibernation fails,
#              the script identifies blocking processes and tries to terminate
#              them before retrying hibernation.
#
# Usage:       This script is intended to be run as a systemd service that triggers
#              automatically before the system enters hibernation.
#
# Systemd Service Setup:
# 1. Make the script executable and place it in /usr/local/bin:
#    sudo mv hibernation_management.sh /usr/local/bin/
#    sudo chmod +x /usr/local/bin/hibernation_management.sh
#
# 2. Create a systemd service file:
#    sudo nano /etc/systemd/system/hibernation_manager.service
#    # Add the contents from the systemd service section below to this file
#
# 3. Reload systemd and enable the service:
#    sudo systemctl daemon-reload
#    sudo systemctl enable hibernation_manager.service
#
# 4. The service will automatically trigger on hibernation attempts.
#
# Systemd Service File Content:
# [Unit]
# Description=Manage Hibernation Attempts
# Before=hibernate.target
# DefaultDependencies=no
#
# [Service]
# Type=oneshot
# ExecStart=/usr/local/bin/hibernation_management.sh
# Environment="LOG_FILE=/var/log/hibernation_log.txt" "HIBERNATION_RETRY_LOG=/var/log/hibernation_retry.log"
# RemainAfterExit=yes
#
# [Install]
# WantedBy=hibernate.target
#
# Dependencies: This script requires `systemctl` for hibernation control, `auditd`
#               for log analysis, and common Linux utilities (`grep`, `pgrep`, `kill`,
#               `cut`, `sort`, `uniq`). Ensure `auditd` is installed and configured:
#               sudo apt-get install auditd
#               echo '-w /sys/power/state -p w -k hibernate-issue' | sudo tee -a /etc/audit/audit.rules
#               sudo systemctl restart auditd
#
# Safety Notes:
# - Contains a whitelist of critical system processes that should not be terminated.
# - Forcefully kills identified non-whitelisted processes that may block hibernation.
# - Use with caution to avoid data loss or system instability.
#
# Limitations:
# - Effectiveness depends on accurate `auditd` log entries.
# - Designed for Ubuntu/Pop!_OS; adjustments may be needed for other distributions.
#################################################################################

# Constants
LOG_FILE="/var/log/hibernation_log.txt"
HIBERNATION_RETRY_LOG="/var/log/hibernation_retry.log"
MAX_KILL_COUNT=3  # Maximum number of processes to kill

# Whitelist of essential Ubuntu/Pop!_OS system processes
declare -a whitelist=(
    "systemd",
    "systemd-journald",
    "systemd-logind",
    "systemd-udevd",
    "networkd-dispatcher",
    "NetworkManager",
    "sshd",
    "cron",
    "dbus-daemon",
    "polkitd",
    "acpid",
    "atd",
    "unattended-upgrades"
)

function attempt_hibernation {
    echo "Attempting hibernation: $(date)" >> $HIBERNATION_RETRY_LOG
    systemctl hibernate
    if [ $? -ne 0 ]; then
        echo "Hibernation failed, analyzing logs..." >> $HIBERNATION_RETRY_LOG
        analyze_and_kill
    else
        echo "Hibernation successful." >> $HIBERNATION_RETRY_LOG
    fi
}

function analyze_and_kill {
    echo "Analyzing audit logs for blocking processes..." >> $HIBERNATION_RETRY_LOG
    local problematic_processes=$(ausearch -k hibernate-issue --raw | grep 'type=OBJ_PID' | grep -o 'ocomm="[^\"]*"' | cut -d'"' -f2 | sort | uniq)
    local kill_count=0

    for proc in $problematic_processes; do
        if [ $kill_count -ge $MAX_KILL_COUNT ]; then
            echo "Reached max kill count limit, stopping further kills." >> $HIBERNATION_RETRY_LOG
            break
        fi
        if [[ ! " ${whitelist[@]} " =~ " ${proc} " ]]; then
            local pids=$(pgrep -x $proc)  # Exact match to process name
            if [ ! -z "$pids" ]; then
                echo "Killing $proc with PIDs: $pids" >> $HIBERNATION_RETRY_LOG
                kill -9 $pids
                ((kill_count++))
            fi
        else
            echo "Process $proc is whitelisted and will not be killed." >> $HIBERNATION_RETRY_LOG
        fi
    done

    if [ $kill_count -gt 0 ]; then
        echo "Retrying hibernation after killing $kill_count processes..." >> $HIBERNATION_RETRY_LOG
        systemctl hibernate
        if [ $? -ne 0 ]; then
            echo "Second hibernation attempt also failed." >> $HIBERNATION_RETRY_LOG
        else
            echo "Hibernation successful on second attempt." >> $HIBERNATION_RETRY_LOG
        fi
    else
        echo "No killable processes found, or no process was killed. No second hibernation attempt made." >> $HIBERNATION_RETRY_LOG
    fi
}

# Initial attempt to hibernate
attempt_hibernation
