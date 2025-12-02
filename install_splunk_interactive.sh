#!/bin/bash
set -e

if [ "$EUID" -ne 0 ]; then
  echo "Please run this script as root."
  exit 1
fi

echo "Splunk interactive installer"

TOTAL_MEM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
TOTAL_MEM_GB=$((TOTAL_MEM_KB / 1024 / 1024))
FREE_ROOT_KB=$(df -Pk / | awk 'NR==2 {print $4}')
FREE_ROOT_GB=$((FREE_ROOT_KB / 1024 / 1024))

echo
echo "Pre-flight check:"
echo "Approx RAM: ${TOTAL_MEM_GB} GB"
echo "Free space on /: ${FREE_ROOT_GB} GB"

WARN=0
if [ "$TOTAL_MEM_GB" -lt 2 ]; then
  echo "Warning: RAM is less than 2 GB."
  WARN=1
fi

if [ "$FREE_ROOT_GB" -lt 10 ]; then
  echo "Warning: Free space on / is less than 10 GB."
  WARN=1
fi

if [ "$WARN" -eq 1 ]; then
  read -rp "System is below recommended specs. Continue anyway? [y/N]: " CONTINUE_ANYWAY
  CONTINUE_ANYWAY=${CONTINUE_ANYWAY,,}
  if [ "$CONTINUE_ANYWAY" != "y" ]; then
    echo "Aborting due to system constraints."
    exit 1
  fi
fi

read -rp "Enter Splunk system user name [splunk]: " SPLUNK_USER
if [ -z "$SPLUNK_USER" ]; then
  SPLUNK_USER="splunk"
fi

if ! id "$SPLUNK_USER" >/dev/null 2>&1; then
  echo "Creating user $SPLUNK_USER"
  adduser --system --home /opt/splunk --group "$SPLUNK_USER"
fi

SPLUNK_HOME="/opt/splunk"
DOWNLOAD_DIR="/opt"
PKG_PATH="$DOWNLOAD_DIR/splunk.tgz"

echo
echo "Choose Splunk version family:"
echo "1) Splunk Enterprise 10.x (recommended)"
echo "2) Splunk Enterprise 9.x"
echo "3) Other version"
read -rp "Enter choice [1-3]: " VERSION_CHOICE

case "$VERSION_CHOICE" in
  1)
    VERSION_LABEL="10.x"
    ;;
  2)
    VERSION_LABEL="9.x"
    ;;
  3)
    VERSION_LABEL="custom"
    ;;
  *)
    echo "Invalid choice"
    exit 1
    ;;
esac

echo
echo "You chose version: $VERSION_LABEL"
read -rp "Enter direct download URL for the Splunk .tgz package: " SPLUNK_URL

if [ -z "$SPLUNK_URL" ]; then
  echo "No URL provided, aborting."
  exit 1
fi

echo
echo "Downloading Splunk from:"
echo "$SPLUNK_URL"
wget -O "$PKG_PATH" "$SPLUNK_URL"

if [ ! -s "$PKG_PATH" ]; then
  echo "Download failed or file is empty."
  exit 1
fi

if [ -d "$SPLUNK_HOME" ]; then
  echo "Directory $SPLUNK_HOME already exists."
  read -rp "Reuse existing directory and overwrite its contents? [y/N]: " REUSE_CHOICE
  REUSE_CHOICE=${REUSE_CHOICE,,}
  if [ "$REUSE_CHOICE" != "y" ]; then
    echo "Aborting to avoid overwriting existing Splunk installation."
    exit 1
  fi
  rm -rf "$SPLUNK_HOME"
fi

tar -xzf "$PKG_PATH" -C /opt

if [ ! -d "$SPLUNK_HOME" ]; then
  echo "Extraction failed, $SPLUNK_HOME not found."
  exit 1
fi

chown -R "$SPLUNK_USER":"$SPLUNK_USER" "$SPLUNK_HOME"

echo
echo "Choose deployment type:"
echo "1) Single-instance (search + index on same node)"
echo "2) Multi-instance (part of distributed deployment)"
read -rp "Enter choice [1-2]: " DEPLOY_CHOICE

if [ "$DEPLOY_CHOICE" = "2" ]; then
  DEPLOY_TYPE="multi"
else
  DEPLOY_TYPE="single"
fi

mkdir -p "$SPLUNK_HOME/etc"
echo "$DEPLOY_TYPE" > "$SPLUNK_HOME/etc/deployment_type"

echo
read -rp "Enter Splunk admin username [admin]: " ADMIN_USER
if [ -z "$ADMIN_USER" ]; then
  ADMIN_USER="admin"
fi

while true; do
  read -s -rp "Enter Splunk admin password: " ADMIN_PASS
  echo
  read -s -rp "Confirm Splunk admin password: " ADMIN_PASS2
  echo
  if [ "$ADMIN_PASS" != "$ADMIN_PASS2" ]; then
    echo "Passwords do not match, try again."
  elif [ -z "$ADMIN_PASS" ]; then
    echo "Password cannot be empty, try again."
  else
    break
  fi
done

mkdir -p "$SPLUNK_HOME/etc/system/local"
USER_SEED="$SPLUNK_HOME/etc/system/local/user-seed.conf"
cat > "$USER_SEED" <<EOF
[user_info]
USERNAME = $ADMIN_USER
PASSWORD = $ADMIN_PASS
EOF
chown "$SPLUNK_USER":"$SPLUNK_USER" "$USER_SEED"

echo
read -rp "Tune system limits (nofile) for Splunk user? [Y/n]: " TUNE_LIMITS
TUNE_LIMITS=${TUNE_LIMITS,,}
if [ -z "$TUNE_LIMITS" ] || [ "$TUNE_LIMITS" = "y" ]; then
  LIMITS_FILE="/etc/security/limits.d/splunk.conf"
  cat > "$LIMITS_FILE" <<EOF
$SPLUNK_USER soft nofile 8192
$SPLUNK_USER hard nofile 16384
EOF
  echo "Limits file written to $LIMITS_FILE"
fi

echo
echo "Starting Splunk for the first time."
sudo -u "$SPLUNK_USER" "$SPLUNK_HOME/bin/splunk" start --accept-license --answer-yes --no-prompt

echo
read -rp "Enable Splunk to start at boot? [Y/n]: " BOOT_START
BOOT_START=${BOOT_START,,}
if [ -z "$BOOT_START" ] || [ "$BOOT_START" = "y" ]; then
  "$SPLUNK_HOME/bin/splunk" enable boot-start -user "$SPLUNK_USER" --answer-yes --no-prompt
fi

echo
read -rp "Do you want to create custom indexes now? [y/N]: " CREATE_IDX
CREATE_IDX=${CREATE_IDX,,}

if [ "$CREATE_IDX" = "y" ]; then
  read -rp "How many indexes do you want to create? (0 for none): " INDEX_COUNT
  if ! [[ "$INDEX_COUNT" =~ ^[0-9]+$ ]]; then
    echo "Invalid number, skipping index creation."
    INDEX_COUNT=0
  fi

  if [ "$INDEX_COUNT" -gt 0 ]; then
    for ((i=1; i<=INDEX_COUNT; i++)); do
      echo
      echo "Index $i of $INDEX_COUNT"
      read -rp "Enter index name: " IDX_NAME
      if [ -z "$IDX_NAME" ]; then
        echo "Empty name, skipping this index."
        continue
      fi

      read -rp "Enter max size in GB for index \"$IDX_NAME\" (example 1 or 5): " IDX_SIZE_GB
      if ! [[ "$IDX_SIZE_GB" =~ ^[0-9]+$ ]]; then
        echo "Invalid size, defaulting to 1 GB."
        IDX_SIZE_GB=1
      fi

      SIZE_MB=$((IDX_SIZE_GB * 1024))

      echo "Creating index $IDX_NAME with maxTotalDataSizeMB=$SIZE_MB"
      sudo -u "$SPLUNK_USER" "$SPLUNK_HOME/bin/splunk" add index "$IDX_NAME" -maxTotalDataSizeMB "$SIZE_MB" -auth "$ADMIN_USER:$ADMIN_PASS" || echo "Failed to create index $IDX_NAME"
    done

    echo
    echo "Restarting Splunk to apply index configuration."
    sudo -u "$SPLUNK_USER" "$SPLUNK_HOME/bin/splunk" restart

    echo
    echo "Current indexes:"
    sudo -u "$SPLUNK_USER" "$SPLUNK_HOME/bin/splunk" list index
  fi
fi

echo
echo "Installation complete."
echo "Splunk home: $SPLUNK_HOME"
echo "Splunk user: $SPLUNK_USER"
echo "Deployment type: $DEPLOY_TYPE"
echo "Admin user: $ADMIN_USER"
echo "Web UI should be available on: http://$(hostname -I | awk '{print $1}'):8000"
