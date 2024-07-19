Hibernation Management Script
=============================

This repository contains a script designed to manage hibernation attempts on Ubuntu/Pop!\_OS systems. The script automates the process of retrying hibernation when the initial attempt fails due to processes blocking the hibernation process.

Description
-----------

The `Hibernation Management Script` helps ensure successful system hibernation by automatically handling processes that may impede the hibernation process. If the system fails to hibernate, the script identifies and terminates these blocking processes and retries the hibernation.

Features
--------

*   **Automatic Retry**: Automatically retries hibernation if the first attempt fails.
*   **Process Management**: Identifies and terminates processes that block hibernation.
*   **Systemd Integration**: Runs as a systemd service triggered by hibernation attempts.

System Requirements
-------------------

*   **Operating System**: Ubuntu or Pop!\_OS.
*   **Dependencies**:
    *   `systemd`: For managing services and hibernation.
    *   `auditd`: For log analysis to identify blocking processes.
    *   Standard Unix utilities: `grep`, `pgrep`, `kill`, `cut`, `sort`, `uniq`.

Installation
------------

1.  **Install Dependencies**:
    
    `sudo apt-get install auditd` 
    
2.  **Configure Auditd**:
       
    ```bash
    echo '-w /sys/power/state -p w -k hibernate-issue' | sudo tee -a /etc/audit/audit.rules
    sudo systemctl restart auditd
    ``` 
    
3.  **Download the Script**: Clone this repository or download the script directly into your preferred directory, such as `/usr/local/bin/`.
    
4.  **Make the Script Executable**:
    
    `sudo chmod +x /usr/local/bin/hibernation_management.sh` 
    
5.  **Set Up the Systemd Service**: Create a systemd service file to manage the script execution:
    
    `sudo nano /etc/systemd/system/hibernation_manager.service` 
    
    Copy the following content into the service file:
    
  ``` bash
    [Unit]
    Description=Manage Hibernation Attempts
    Before=hibernate.target
    DefaultDependencies=no
    
    [Service]
    Type=oneshot
    ExecStart=/usr/local/bin/hibernation_management.sh
    Environment="LOG_FILE=/var/log/hibernation_log.txt" "HIBERNATION_RETRY_LOG=/var/log/hibernation_retry.log"
    RemainAfterExit=yes
    
    [Install]
    WantedBy=hibernate.target
``` 
    
6.  **Enable and Start the Service**:
       
    `sudo systemctl daemon-reload
    sudo systemctl enable hibernation_manager.service` 

Usage
-----

Once installed and enabled, the service will trigger automatically when the system attempts to hibernate. If the hibernation fails, the script will analyze the situation, kill any problematic processes (excluding those on the whitelist), and retry the hibernation.  

Whitelist Configuration
-----------------------

Review and modify the whitelist in the script to ensure critical system processes are not terminated. Although it is unlikely that auditd would log a core OS process as a blocker, or that the script would go on an indiscriminate killing rampage (perhaps as a result of a parsing error/unanticipated edge case), this is a recommended precaution for ensuring system stability. As an additional guardrail, the script will not kill more processes than the max specified with MAX_KILL_COUNT (arbitrarily set to 3 in the repo).

Contributing
------------

Contributions to this project are welcome. Please fork the repository and submit pull requests with your enhancements.

License
-------

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details. 

No Claims or Guarantees
------------

Note that while this appears to work very well on a Lenovo P1 running Pop!_OS 22.04 LTS, I make absolutely no claims that it will work for you.  Excercise caution, common sense, and do plenty of testing!!
