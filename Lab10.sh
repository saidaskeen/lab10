#!/bin/bash


# This takes in the first argument (after the script) and calls it the service type variable
servicetype=$(echo "$1" | tr '[:lower:]' '[:upper:]')



# This makes sure that the script is being run with the correct permissions (root)
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root." >&2
    exit 1
fi


dns="DNS"
web="WEB"
ftp="FTP"
data="DATABASE"
back="BACKUP"

# Handels cases were the user does not add a service
if [ "$servicetype" != "$dns" ] && [ "$servicetype" != "$web" ] && [ "$servicetype" != "$ftp" ] && [ "$servicetype" != "$data" ]; then
    echo "Error: Unsupported servicetype '$servicetype'. Please provide one of the following: DNS, WEB, FTP, DATABASE."
    exit 1
fi


# This will emable logging
log_file="/var/log/firewall_config.log"
mkdir -p $(dirname "$log_file")
touch "$log_file"
exec > >(tee -a "$log_file") 2>&1

# This will create a log directory and redirect the output to the log
mkdir -p "$(dirname "$log_file")"
touch "$log_file"
exec > >(tee -a "$log_file") 2>&1

# This enables UFW and sets up default policys like default deny both incoming and outgoing, and starting logging
echo Automated Firewall Configuration for $servicetype on $OSTYPE will now begin
ufw --force reset
ufw default deny incoming
ufw default deny outgoing
ufw logging on
ufw enable


# DNS setup function
setup_dns() {
    echo "Now configuring DNS firewall rules..."
    ufw allow 22/tcp
    ufw allow 53/tcp
    while true; do
        read -p "Enter an IP to block (press Enter with no input if there are none/no more): " toblock
        [[ -z "$toblock" ]] && break
        ufw deny from "$toblock"
    done
}

# Web setup function
setup_web() {
    echo "Now configuring web firewall rules..."
    ufw allow 22/tcp
    ufw allow 80/tcp
    ufw allow 443/tcp

    echo "Now setting up HTTP and HTTPS restrictions..."
    while true; do
        read -p "Enter an IP to BLOCK for HTTP/HTTPS (press Enter to skip): " blockip
        [[ -z "$blockip" ]] && break
        ufw deny from "$blockip" to any port 80 proto tcp
        ufw deny from "$blockip" to any port 443 proto tcp
    done
}

# ftp setup function
setup_ftp() {
    echp "Now configuring FTP firewall rules"
    ufw allow 22/tcp
    ufw allow 21/tcp
    ufw allow 20/tcp
    ufw allow 30000:31000/tcp

    echo "Enter IPs to BLOCK from FTP access (control, data, passive). Press Enter to skip."
    while true; do
        read -p "IP to block: " blockftp
        [[ -z "$blockftp" ]] && break
        ufw deny proto tcp from "$blockftp" to any port 21
        ufw deny proto tcp from "$blockftp" to any port 20
        ufw deny proto tcp from "$blockftp" to any port 30000:31000
    done

    echo "Enter IPs to BLOCK from SSH (port 22). Press Enter to skip."
    while true; do
        read -p "IP to block: " blockssh
        [[ -z "$blockssh" ]] && break
        ufw deny proto tcp from "$blockssh" to any port 22
    done
}

# Database setup function
setup_database() {
    echo "Setting up Database firewall rules now..."
    ufw allow 5432/tcp
    ufw allow 22/tcp
    echo "Enter IPs to BLOCK from all traffic (TCP and UDP). Press Enter with no input to finish."
    while true; do
        read -p "IP to block: " blockdb
        [[ -z "$blockdb" ]] && break
        ufw deny tcp from "$blockdb"
        ufw deny udp from "$blockdb"
    done
}

# Backup setup function
setup_backup() {
    ufw allow 22/tcp
    ufw allow 873/tcp

    echo "Enter IPs allowed to connect to the backup service (e.g., central backup server)."
    while true; do
        read -p "IP to allow for BACKUP: " allowbackup
        [[ -z "$allowbackup" ]] && break
        ufw allow from "$allowbackup" to any port 873 proto tcp
    done

    echo "Enter IPs to BLOCK from accessing backup services (SSH or rsync). Press Enter with no input to finish."
    while true; do
        read -p "IP to block: " blockbackup
        [[ -z "$blockbackup" ]] && break
        ufw deny proto tcp from "$blockbackup" to any port 22
        ufw deny proto tcp from "$blockbackup" to any port 873
    done
}

# This makes sure that the user input initaites the correct function
case "$servicetype" in
    "$dns") setup_dns ;;
    "$web") setup_web ;;
    "$ftp") setup_ftp ;;
    "$data") setup_database ;;
    "$back") setup_backup ;;
    *) echo "Unknown service type."; exit 1 ;;
esac

echo "Firewall configuration for $servicetype complete."
ufw status verbose




# if [ "$servicetype" == "$dns" ]; then
# ufw allow 22/tcp
# ufw allow 53/tcp
# while true; do
#         read -p "Enter an IP to block (press Enter with no input if there are none/no more): " toblock
#         if [ -z "$toblock" ]; then
#             break
#         fi
#         ufw deny from "$toblock"
#     done
# fi



# #default deny incoming let out everything let in port 53
# if [ "$servicetype" == "$web" ]; then
#    # Allow basic services
#     ufw allow 22/tcp    # SSH
#     ufw allow 80/tcp    # HTTP
#     ufw allow 443/tcp   # HTTPS

#     # Enable logging
#     ufw logging on  # Logs blocked packets and some allowed ones by default

#     echo "Now setting up HTTP and HTTPS restrictions..."
#     while true; do
#         read -p "Enter an IP to BLOCK for HTTP/HTTPS (press Enter to skip): " blockip
#         if [ -z "$blockip" ]; then
#             break
#         fi
#         ufw deny from "$blockip" to any port 80 proto tcp
#         ufw deny from "$blockip" to any port 443 proto tcp
#     done

#     echo "Now setting up SSH restrictions..."
#     while true; do
#         read -p "Enter an IP to ALLOW SSH (press Enter to skip): " allowssh
#         if [ -z "$allowssh" ]; then
#             break
#         fi
#         ufw allow from "$allowssh" to any port 22 proto tcp
#     done

#     while true; do
#         read -p "Enter an IP to BLOCK SSH (press Enter to skip): " blockssh
#         if [ -z "$blockssh" ]; then
#             break
#         fi
#         ufw deny from "$blockssh" to any port 22 proto tcp
#     done
# fi



# if [ "$servicetype" == "$ftp" ]; then
# ufw allow 22/tcp

#     # FTP Access
#     ufw allow 21/tcp       # FTP command/control
#     ufw allow 20/tcp       # FTP data (active)
#     ufw allow 30000:31000/tcp  # Passive mode ports

#     # Logging
#     ufw logging on

#     echo "Enter IPs to BLOCK from FTP access (control, data, passive). Press Enter to skip."
#     while true; do
#         read -p "IP to block: " blockftp
#         if [ -z "$blockftp" ]; then
#             break
#         fi
#         ufw deny proto tcp from "$blockftp" to any port 21
#         ufw deny proto tcp from "$blockftp" to any port 20
#         ufw deny proto tcp from "$blockftp" to any port 30000:31000
#     done

#     echo "Enter IPs to BLOCK from SSH (port 22). Press Enter to skip."
#     while true; do
#         read -p "IP to block: " blockssh
#         if [ -z "$blockssh" ]; then
#             break
#         fi
#         ufw deny proto tcp from "$blockssh" to any port 22
#     done
# fi

# # Database firewall configuration
# if [ "$servicetype" == "$data" ]; then
# ufw allow 5432/tcp
# ufw allow 22/tcp
# ufw logging on
# echo "Enter IPs to BLOCK from all traffic (TCP and UDP). Press Enter with no input to finish."
#     while true; do
#         read -p "IP to block: " blockdb
#         if [ -z "$blockdb" ]; then
#             break
#         fi
#         ufw deny proto tcp from "$blockdb"
#         ufw deny proto udp from "$blockdb"
#     done


# fi



# if [ "$servicetype" == "$back" ]; then
#     ufw allow 22/tcp         # SSH for secure backups
#     ufw allow 873/tcp        # rsync daemon 
#     ufw logging on
#     echo "Enter IPs allowed to connect to the backup service (e.g., central backup server)."
#     while true; do
#         read -p "IP to allow for BACKUP: " allowbackup
#         if [ -z "$allowbackup" ]; then
#             break
#         fi
#         ufw allow from "$allowbackup" to any port 873 proto tcp
#     done

#     echo "Enter IPs to BLOCK from accessing backup services (SSH or rsync). Press Enter with no input to finish."
#     while true; do
#         read -p "IP to block: " blockbackup
#         if [ -z "$blockbackup" ]; then
#             break
#         fi
#         ufw deny proto tcp from "$blockbackup" to any port 22
#         ufw deny proto tcp from "$blockbackup" to any port 873
#     done
# fi








