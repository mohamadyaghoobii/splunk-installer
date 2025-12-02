# Splunk Interactive Installer

An opinionated, interactive shell installer for Splunk Enterprise on Linux, focused on **small test / lab environments** and **fast clean installs**.

This repository contains a single script:

- `install_splunk_interactive.sh`

The script walks you through installing Splunk Enterprise from an official `.tgz` URL, creating a dedicated system user, and (optionally) creating a few small custom indexes for your lab.

> هدف این اسکریپت این است که نصب اسپلانک روی سرورهای تست و لاب را خیلی سریع، تمیز و قابل تکرار کند.

---

## Features

- Interactive menu for **Splunk version family**:
  - 10.x
  - 9.x
  - Custom (any `.tgz` URL)
- Installs Splunk from official `.tgz` package under `/opt/splunk`
- Creates a dedicated **system user** for Splunk (default: `splunk` or your choice)
- Supports **single-instance** (search + index on same node) and basic multi-instance role choice
- First-time **admin user** and password setup
- Optional creation of **custom indexes**:
  - Ask how many indexes to create
  - Ask name of each index
  - Ask max size in GB per index and converts to `maxTotalDataSizeMB`
- Configures Splunk to:
  - Start at boot (SysV init script)
  - Start Splunk for the first time
- Prints the final **Web UI URL** at the end (for example `http://10.10.14.17:8000`)

---

## Requirements

Tested on:

- Ubuntu Server 22.04 LTS (64‑bit)
- 2 GB RAM (minimum for a small lab)
- A few GB free disk space under `/opt`

You should have:

- Root access (or sudo)
- Network access to `download.splunk.com` to fetch the Splunk `.tgz`
- A valid Splunk download URL (for example a 10.x `.tgz` URL from the official Splunk downloads page)

---

## What the script does (high level)

1. Checks that it is running as **root**.
2. Asks for the Splunk **system user** name, creates it if needed (as a system user with home `/opt/splunk`).
3. Lets you choose the **version family**:
   - 10.x
   - 9.x
   - Custom
4. Prompts for the **direct download URL** of the Splunk `.tgz` package.
5. Downloads the package to `/opt/splunk.tgz`.
6. Extracts Splunk under `/opt/splunk`.
7. Asks for **deployment type**:
   - Single-instance
   - Multi-instance (for distributed setups; script only sets basic role, full clustering is out-of-scope)
8. Prompts for:
   - Splunk **admin username**
   - Splunk **admin password** (with confirmation)
9. Runs Splunk for the first time with the provided admin credentials.
10. Optionally:
    - Asks whether you want to create **custom indexes**.
    - For each index:
      - Asks for index name.
      - Asks for max size in GB.
      - Calls `splunk add index` with `-maxTotalDataSizeMB` based on your input.
11. Restarts Splunk to apply index configuration.
12. Prints a summary:
    - Splunk home directory
    - Splunk system user
    - Deployment type
    - Admin user
    - Web UI URL

---

## Usage

### 1. Clone the repository

```bash
cd ~
git clone https://github.com/mohamadyaghoobii/splunk-installer.git
cd splunk-installer
```

Or simply copy the script into a new directory:

```bash
mkdir -p ~/splunk-installer
cd ~/splunk-installer
# Copy install_splunk_interactive.sh here
chmod +x install_splunk_interactive.sh
```

### 2. Run the installer as root

```bash
sudo ./install_splunk_interactive.sh
```

The script will ask you:

1. Splunk system user name (default: `splunk`).
2. Version family (10.x / 9.x / custom).
3. Direct download URL of the Splunk `.tgz`.
4. Deployment type (single-instance / multi-instance).
5. Splunk admin username and password.
6. Whether you want to create custom indexes (and if yes, their names and sizes).

At the end, you should see something like:

```text
Installation complete.
Splunk home: /opt/splunk
Splunk user: ojan-splunk
Deployment type: single
Admin user: ojan-splunk
Web UI should be available on: http://10.10.14.17:8000
```

Open the Web UI in your browser and log in with the admin credentials you entered.

---

## Notes and Best Practices

- This script is designed for **lab / test environments**, not for large production clusters.
- Always download Splunk from the official site and copy the **exact** `.tgz` URL.
- For small test indexes, 1–5 GB per index is usually enough.
- You can always manage indexes later from:
  - `$SPLUNK_HOME/etc/system/local/indexes.conf`
  - Or via `Settings → Indexes` in the Splunk Web UI.

---

## Updating Splunk

To upgrade Splunk using a newer `.tgz` manually:

1. Stop Splunk:

   ```bash
   sudo /opt/splunk/bin/splunk stop
   ```

2. Download the new `.tgz` under `/opt`.
3. Extract it on top of the existing installation (or use your own controlled process).
4. Start Splunk again:

   ```bash
   sudo /opt/splunk/bin/splunk start
   ```

**Important:** Always back up `$SPLUNK_HOME/etc` before major upgrades.

---

## Troubleshooting

- **Port 8000 already in use**  
  Make sure no other service is listening on port `8000` or change `web.conf` to use a different port.

- **Cannot reach Web UI**  
  Check firewall rules and verify that the server IP and port are reachable:
  ```bash
  curl -vk http://127.0.0.1:8000
  ```

- **Forgot admin password**  
  You can use `user-seed.conf` or standard Splunk password reset procedures (see Splunk docs).

---

## Roadmap / Ideas

Possible future improvements for this installer:

- Non-interactive mode (environment variables / flags) for automation.
- Automatic download of the latest Splunk version (using the Splunk download API).
- Optional configuration for:
  - Receiving syslog
  - Common test indexes (Windows, Linux, firewall, etc.)
- Health checks after installation (ports, services, disk space).

---

## License

This project is provided as-is for lab and testing use.  
Review and adapt the script before using it in sensitive or production environments.
