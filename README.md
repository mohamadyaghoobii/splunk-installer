# Splunk Interactive Installer

An interactive shell-based installer for **Splunk Enterprise** on Linux, focused on clean, repeatable installs and quick initial configuration for real deployments.

This repository currently contains a single main script:

- `install_splunk_interactive.sh`

The script guides you through installing Splunk Enterprise from an official `.tgz` URL, creating a dedicated system user, choosing deployment type, and optionally creating custom indexes.

---

## Overview

```text
┌────────────┐       ┌──────────────────────────────┐       ┌───────────────────┐
│   Admin    │  ==>  │ install_splunk_interactive.sh│  ==>  │ Splunk Enterprise │
└────────────┘       └──────────────────────────────┘       └───────────────────┘
      │                         │                                   │
      │                         │                                   │
      ▼                         ▼                                   ▼
 Choose version          Download & install                 Ready to use:
, user, role, indexes    Configure and start               web UI, indexes, admin
```

This installer is designed to be:

- **Structured** – always follows the same steps in the same order
- **Safe** – uses a dedicated system user and `/opt/splunk` layout
- **Flexible** – supports different Splunk versions and deployment roles
- **Extensible** – you can easily extend it with your own automation

---

## Features

- Interactive menu for **Splunk version family**:
  - 10.x
  - 9.x
  - Custom (any valid Splunk Enterprise `.tgz` URL)
- Downloads and installs from official Splunk `.tgz` packages under `/opt/splunk`
- Creates a dedicated **system user** for Splunk (default: `splunk` or a custom username)
- Supports choosing deployment type:
  - **Single-instance** (search head and indexer on the same node)
  - **Multi-instance** role choice (basic role selection; full clustering configuration is intentionally left to Splunk administrators)
- First-time **admin user** and password setup
- Optional creation of **custom indexes**:
  - Ask how many indexes to create
  - Ask name of each index
  - Ask max size in GB per index and converts it to `maxTotalDataSizeMB`
- Configures Splunk to:
  - Start at boot using an init script
  - Start Splunk for the first time with the chosen admin credentials
- Prints a final summary including:
  - Splunk home directory
  - Splunk system user
  - Deployment type
  - Admin user
  - Web UI URL (for example `http://10.10.14.17:8000`)

---

## Requirements

Tested with:

- Linux: Ubuntu Server 22.04 LTS (64-bit)
- CPU: x86_64
- Memory: 2 GB or more
- Disk: enough free space under `/opt` to hold the Splunk binaries and your initial indexes

You should have:

- Root access (or `sudo`)
- Network access to `download.splunk.com` (or to your internal Splunk download mirror)
- A valid Splunk Enterprise `.tgz` URL, for example:
  - `https://download.splunk.com/products/splunk/releases/10.x.x/linux/splunk-10.x.x-<build>-linux-amd64.tgz`

---

## What the script does

High-level flow:

1. Verify that the script is running as **root**.
2. Ask for the Splunk **system user** name:
   - Create the user as a system user with home `/opt/splunk` if it does not exist.
3. Let you choose the **version family**:
   - 10.x
   - 9.x
   - Custom
4. Prompt for the **direct download URL** of the Splunk Enterprise `.tgz` package.
5. Download the package to `/opt/splunk.tgz`.
6. Extract Splunk into `/opt/splunk`.
7. Ask for the **deployment type**:
   - Single-instance
   - Multi-instance (role only; advanced topology and clustering are not configured by this script)
8. Prompt for Splunk **admin username** and **password** (with confirmation).
9. Run Splunk for the first time with the provided admin credentials and accept the license via CLI.
10. Optionally:
    - Ask whether you want to create **custom indexes**.
    - For each index:
      - Ask for index name.
      - Ask for max size in GB.
      - Call `splunk add index` with `-maxTotalDataSizeMB` based on your input.
11. Restart Splunk to apply index configuration.
12. Display a final summary including the Web UI URL.

---

## Usage

### 1. Clone the repository

```bash
cd ~
git clone https://github.com/mohamadyaghoobii/splunk-installer.git
cd splunk-installer
```

Or create the directory manually and copy the script:

```bash
mkdir -p ~/splunk-installer
cd ~/splunk-installer
chmod +x install_splunk_interactive.sh
```

### 2. Run the installer

Run as root (or via sudo):

```bash
sudo ./install_splunk_interactive.sh
```

You will be prompted for:

1. Splunk system user name.
2. Version family (10.x / 9.x / custom).
3. Direct download URL for the Splunk `.tgz`.
4. Deployment type (single-instance or multi-instance).
5. Admin username and password.
6. Whether to create custom indexes and their details.

At the end, you should see a summary similar to:

```text
Installation complete.
Splunk home: /opt/splunk
Splunk user: ojan-splunk
Deployment type: single
Admin user: ojan-splunk
Web UI should be available on: http://10.10.14.17:8000
```

Open the Web UI in your browser using the printed URL and log in with the admin credentials you entered.

---

## Best practices

- Always download Splunk from trusted and official sources.
- Keep a record of the exact Splunk version you deployed (10.x build, etc.).
- Limit initial index sizes to what makes sense for your disk layout; you can adjust them later in:
  - `$SPLUNK_HOME/etc/system/local/indexes.conf`
  - Splunk Web UI: Settings → Indexes
- Regularly back up:
  - `$SPLUNK_HOME/etc` (configuration)
  - Index data locations, depending on your retention and backup policies.

---

## Extending the installer

The script is intentionally written as a simple, readable shell installer so it can be extended. Some ideas for future enhancements:

- Non-interactive mode:
  - Support environment variables or flags for fully automated deployments.
- Automatic detection of the latest Splunk Enterprise version in a family.
- Optional post-install configuration:
  - Inputs and data collection (syslog, Windows Event Logs, etc.).
  - Basic apps or technology add-ons.
- Health checks after installation:
  - Verify ports and services.
  - Check disk space and resource usage.

You can fork this repository and adapt the installer to your own standards and production policies.

---

## Troubleshooting

Common checks:

- Verify that Splunk is running:

  ```bash
  sudo /opt/splunk/bin/splunk status
  ```

- Restart Splunk:

  ```bash
  sudo /opt/splunk/bin/splunk restart
  ```

- Check local access to the Web UI:

  ```bash
  curl -vk http://127.0.0.1:8000
  ```

If you change ports or SSL settings, update your firewall and any reverse proxy configurations accordingly.

---

## License

This installer is provided as-is.  
Review the script and adapt it to your environment, standards, and security requirements before using it in production.
