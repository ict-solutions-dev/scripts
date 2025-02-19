#!/bin/bash

# Define paths and variables
TEMP_DIR="/tmp/freeradius-default"
CURRENT_PATH="/etc/freeradius/3.0"
GITHUB_REPO="https://raw.githubusercontent.com/FreeRADIUS/freeradius-server/v3.0.x/raddb"

# Progress counters
total_files=0
processed_files=0
modified_files=0

# Create and clean temp directory
rm -rf "$TEMP_DIR"
mkdir -p "$TEMP_DIR"

echo "# FreeRADIUS Configuration Comparison Report" > "$TEMP_DIR/report.md"
echo "Generated on: $(date)" >> "$TEMP_DIR/report.md"
echo "" >> "$TEMP_DIR/report.md"

# First, get list of all files from GitHub
echo "🔄 Step 1: Downloading file list from GitHub..."
curl -s "https://api.github.com/repos/FreeRADIUS/freeradius-server/git/trees/v3.0.x?recursive=1" | \
    grep -o '"path": "raddb/[^"]*"' | \
    cut -d'"' -f4 | \
    sed 's/^raddb\///' > "$TEMP_DIR/github_files.txt"

total_files=$(wc -l < "$TEMP_DIR/github_files.txt")
echo "📋 Found $total_files files to check in default configuration"

# Get list of local files
echo "🔍 Step 2: Scanning local installation..."
find "$CURRENT_PATH" -type f -printf "%P\n" > "$TEMP_DIR/local_files.txt"
local_files=$(wc -l < "$TEMP_DIR/local_files.txt")
echo "📋 Found $local_files files in local installation"

echo "## Added Files" >> "$TEMP_DIR/report.md"
echo "Files present in local installation but not in default configuration:" >> "$TEMP_DIR/report.md"
echo "\`\`\`" >> "$TEMP_DIR/report.md"
grep -vxf "$TEMP_DIR/github_files.txt" "$TEMP_DIR/local_files.txt" >> "$TEMP_DIR/report.md"
echo "\`\`\`" >> "$TEMP_DIR/report.md"
echo "" >> "$TEMP_DIR/report.md"

echo "## Modified Default Files" >> "$TEMP_DIR/report.md"
echo "🔄 Step 3: Comparing files..."

# Compare common files
while IFS= read -r file; do
    if [ -f "$CURRENT_PATH/$file" ]; then
        # Create necessary directories in temp
        mkdir -p "$TEMP_DIR/$(dirname $file)"

        # Download original file from GitHub
        curl -s "$GITHUB_REPO/$file" -o "$TEMP_DIR/$file"

        # Update progress
        processed_files=$((processed_files + 1))
        printf "\r⏳ Progress: [%-50s] %d%%" "$(printf '#%.0s' $(seq 1 $(($processed_files * 50 / $total_files))))" $(($processed_files * 100 / $total_files))

        # Compare files, excluding Id changes
        if ! diff -I '^\s*#.*\$Id.*\$' -q "$TEMP_DIR/$file" "$CURRENT_PATH/$file" >/dev/null 2>&1; then
            modified_files=$((modified_files + 1))
            echo -e "\n📝 Found changes in: $file"
            echo "### $file" >> "$TEMP_DIR/report.md"
            echo "\`\`\`diff" >> "$TEMP_DIR/report.md"
            diff -I '^\s*#.*\$Id.*\$' -u "$TEMP_DIR/$file" "$CURRENT_PATH/$file" | \
            grep -v "^---" | grep -v "^+++" | \
            grep -v "^@@" >> "$TEMP_DIR/report.md"
            echo "\`\`\`" >> "$TEMP_DIR/report.md"
            echo "" >> "$TEMP_DIR/report.md"
        fi
    fi
done < "$TEMP_DIR/github_files.txt"
echo -e "\n✅ File comparison complete! Found $modified_files modified files."

# Check for enabled modules
echo "## Enabled Modules" >> "$TEMP_DIR/report.md"
echo "List of enabled modules in mods-enabled:" >> "$TEMP_DIR/report.md"
echo "\`\`\`" >> "$TEMP_DIR/report.md"
ls -l "$CURRENT_PATH/mods-enabled" | awk '{print $9}' | grep -v '^$' >> "$TEMP_DIR/report.md"
echo "\`\`\`" >> "$TEMP_DIR/report.md"
echo "" >> "$TEMP_DIR/report.md"

# Check for enabled sites
echo "## Enabled Sites" >> "$TEMP_DIR/report.md"
echo "List of enabled sites in sites-enabled:" >> "$TEMP_DIR/report.md"
echo "\`\`\`" >> "$TEMP_DIR/report.md"
ls -l "$CURRENT_PATH/sites-enabled" | awk '{print $9}' | grep -v '^$' >> "$TEMP_DIR/report.md"
echo "\`\`\`" >> "$TEMP_DIR/report.md"

echo -e "\n📊 Summary:"
echo "- Total files checked: $total_files"
echo "- Modified files: $modified_files"
echo "- Local files: $local_files"
echo -e "\n📄 Report generated at $TEMP_DIR/report.md"
cat "$TEMP_DIR/report.md"

# Cleanup
rm -rf "$TEMP_DIR"
