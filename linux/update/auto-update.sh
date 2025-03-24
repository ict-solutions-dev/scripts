#!/bin/bash

# Configuration
TOKEN="TOKEN"
OWNER="OWNER"
REPO="REPO"
API_URL="https://api.github.com/repos/$OWNER/$REPO"
OUTPUT_DIR="github_stats"

mkdir -p "$OUTPUT_DIR"

# Get last day of month for macOS
get_last_day_of_month() {
    local year=$1
    local month=$2
    date -j -f "%Y-%m-%d" "${year}-${month}-01" -v+1m -v-1d "+%Y-%m-%d"
}

# Check rate limits and wait if necessary
check_rate_limit() {
    local rate_limit=$(curl -s -H "Authorization: token $TOKEN" \
                            https://api.github.com/rate_limit)
    local remaining=$(echo "$rate_limit" | jq .rate.remaining)
    local reset_time=$(echo "$rate_limit" | jq .rate.reset)

    if [ "$remaining" -lt 10 ]; then
        local current_time=$(date +%s)
        local wait_time=$((reset_time - current_time))
        echo "Rate limit nearly exceeded. Waiting ${wait_time} seconds..."
        sleep "$wait_time"
    fi
}

# API call with rate limit handling
gh_api_call() {
    check_rate_limit
    curl -s -H "Authorization: token $TOKEN" \
         -H "Accept: application/vnd.github.v3+json" \
         "$1"
}

get_month_stats() {
    local year=$1
    local month=$2
    local start_date="${year}-${month}-01"
    local end_date=$(get_last_day_of_month "$year" "$month")

    # Get commits for the month
    commits_response=$(gh_api_call "$API_URL/commits?since=${start_date}T00:00:00Z&until=${end_date}T23:59:59Z&per_page=100")
    commits=$(echo "$commits_response" | jq --arg year "$year" --arg month "$month" '
        [.[] | select(.commit.author.date | startswith($year + "-" + $month))]
    ')

    # Calculate active days
    active_days=$(echo "$commits" | jq -r '.[].commit.author.date' | cut -d'T' -f1 | sort -u | wc -l | tr -d ' ')
    echo "$month/$year: $active_days active days"
}

echo "# GitHub Monthly Statistics" > "$OUTPUT_DIR/monthly_stats.md"
echo "Generated on: $(date)" >> "$OUTPUT_DIR/monthly_stats.md"
echo "" >> "$OUTPUT_DIR/monthly_stats.md"

# Get statistics for the last 12 months
current_year=$(date +%Y)
current_month=$(date +%m)

echo "## Active Days by Month" >> "$OUTPUT_DIR/monthly_stats.md"
for ((i=0; i<12; i++)); do
    if [ $current_month -eq 0 ]; then
        current_month=12
        ((current_year--))
    fi

    # Format month with leading zero if needed
    month_padded=$(printf "%02d" $current_month)

    # Get and append stats for this month
    stats=$(get_month_stats $current_year $month_padded)
    echo "- $stats" >> "$OUTPUT_DIR/monthly_stats.md"

    ((current_month--))
done

echo "Report generated in $OUTPUT_DIR/monthly_stats.md"
