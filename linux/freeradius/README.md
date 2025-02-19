# FreeRADIUS Configuration Comparison Tool

A bash script that compares your local FreeRADIUS configuration with the official default configuration from the FreeRADIUS GitHub repository.

## Overview

This script helps system administrators identify:
- Modified configuration files
- Custom added files
- Enabled modules and sites
- Differences between local and default configurations

## Prerequisites

- Bash shell
- curl
- diff
- grep
- Git (for version information)
- Access to GitHub (https://github.com/FreeRADIUS/freeradius-server)
- FreeRADIUS v3.0.x installed

## Installation

```bash
# Clone the repository
git clone https://github.com/ict-solutions-dev/scripts.git
cd scripts/linux/freeradius

# Make the script executable
chmod +x compare-freeradius.sh
```

## Usage

```bash
./compare-freeradius.sh
```

## Output

The script generates a detailed Markdown report containing:
1. List of added files (not present in default configuration)
2. Modified default files with diff output
3. List of enabled modules
4. List of enabled sites

The report is displayed in the terminal and temporarily saved to `/tmp/freeradius-default/report.md`.

## Directory Structure

The script expects the following FreeRADIUS directory structure:
```
/etc/freeradius/3.0/
├── mods-enabled/
├── sites-enabled/
└── [configuration files]
```

## Features

- 📊 Progress indication during comparison
- 🔍 Detailed diff output for modified files
- 🚫 Ignores CVS/SVN Id changes in files
- 📝 Markdown formatted report
- 🔄 Automatic cleanup of temporary files

## Limitations

- Requires internet connection to access GitHub
- Assumes FreeRADIUS v3.0.x configuration layout
- Requires read access to FreeRADIUS configuration directory
