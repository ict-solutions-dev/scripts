#!/bin/bash

# Load environment variables from .env file
if [ -f .env ]; then
    source .env
else
    echo "Error: .env file not found"
    exit 1
fi

# PowerDNS API configuration with defaults
PDNS_API_URL="${PDNS_API_URL:-http://localhost:8081}"
PDNS_API_KEY="${PDNS_API_KEY}"
SERVER_ID="${SERVER_ID:-localhost}"

# Validate required environment variables
if [ "$PDNS_API_KEY" = "your-api-key" ]; then
    echo "Error: PDNS_API_KEY not configured in .env file"
    exit 1
fi

# Array of zones to exclude
EXCLUDED_ZONES=(
    "64.100.in-addr.arpa.",
    "168.237.91.in-addr.arpa.",
    "169.237.91.in-addr.arpa.",
    "170.237.91.in-addr.arpa.",
    # Add more zones to exclude here
)

# Function to show usage
show_usage() {
    echo "Usage: $0 [COMMAND] [ARGS...]"
    echo "Commands:"
    echo "  list                     - List all reverse zones"
    echo "  get-records ZONE         - Get PTR records for specific zone"
    echo "  get-reverse-zone IP      - Get reverse zone for IP"
    echo "  create-ptr IP HOSTNAME   - Create PTR record for IP with hostname"
    echo "  process-zone ZONE        - Process single zone"
    echo "  update-all               - Update all zones (default)"
    echo
    echo "Examples:"
    echo "  $0 list"
    echo "  $0 get-records 0.168.192.in-addr.arpa."
    echo "  $0 get-reverse-zone 192.168.0.1"
    echo "  $0 create-ptr 192.168.0.1 host-1-0-168-192.e-max.sk."
    echo "  $0 process-zone 0.168.192.in-addr.arpa."
    exit 1
}

# Function to check if zone should be excluded
is_excluded_zone() {
    local check_zone=$1
    for excluded in "${EXCLUDED_ZONES[@]}"; do
        if [[ "$check_zone" == "$excluded" ]]; then
            return 0
        fi
    done
    return 1
}

# Function to convert IP to reverse format
ip_to_reverse() {
    local ip=$1
    IFS='.' read -r a b c d <<< "$ip"
    echo "${d}-${c}-${b}-${a}"
}

# Function to get reverse zone for an IP
get_reverse_zone() {
    local ip=$1
    IFS='.' read -r a b c d <<< "$ip"
    echo "${c}.${b}.${a}.in-addr.arpa"
}

# Function to list all reverse zones
list_reverse_zones() {
    curl -s -H "X-API-Key: ${PDNS_API_KEY}" \
        "${PDNS_API_URL}/api/v1/servers/${SERVER_ID}/zones" | \
        jq -r '.[] | select(.name | endswith(".in-addr.arpa.")) | .name'
}

# Function to get existing PTR records for a zone
get_zone_records() {
    local zone=$1
    curl -s -H "X-API-Key: ${PDNS_API_KEY}" \
        "${PDNS_API_URL}/api/v1/servers/${SERVER_ID}/zones/${zone}" | \
        jq -r '.rrsets[] | select(.type=="PTR") | .name'
}

# Function to create PTR record
create_ptr_record() {
    local ip=$1
    local hostname=$2
    local zone=$(get_reverse_zone "$ip")
    IFS='.' read -r a b c d <<< "$ip"

    local json_data="{
        \"rrsets\": [{
            \"name\": \"${d}.${zone}.\",
            \"type\": \"PTR\",
            \"ttl\": 3600,
            \"changetype\": \"REPLACE\",
            \"records\": [{
                \"content\": \"${hostname}\",
                \"disabled\": false
            }]
        }]
    }"

    curl -s -X PATCH -H "X-API-Key: ${PDNS_API_KEY}" \
         -H "Content-Type: application/json" \
         -d "${json_data}" \
         "${PDNS_API_URL}/api/v1/servers/${SERVER_ID}/zones/${zone}"
}

# Add logging configuration
LOG_FILE="/var/log/pdns-ptr-update.log"
PROCESSED_ZONES=0
CREATED_RECORDS=0
SKIPPED_ZONES=0

# Function to log messages
log_message() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] $1" | tee -a "$LOG_FILE"
}

# Add summary function
print_summary() {
    log_message "=== Summary ==="
    log_message "Processed zones: $PROCESSED_ZONES"
    log_message "Created PTR records: $CREATED_RECORDS"
    log_message "Skipped zones: $SKIPPED_ZONES"
    log_message "=============="
}

# Update process_zone function
process_zone() {
    local zone=$1

    # Check if zone should be excluded
    if is_excluded_zone "$zone"; then
        log_message "Skipping excluded zone: $zone"
        ((SKIPPED_ZONES++))
        return
    }

    log_message "Processing zone: $zone"
    ((PROCESSED_ZONES++))

    # ...existing network_parts and existing_records code...

    # Check all possible IPs in the /24 zone
    for i in {0..255}; do
        local ip="${network_prefix}.$i"
        local ptr_name="${i}.${zone}."

        if ! echo "$existing_records" | grep -q "^${ptr_name}$"; then
            log_message "Adding missing PTR record for $ip"
            local reverse_hostname="host-$(ip_to_reverse "$ip")"
            create_ptr_record "$ip" "${reverse_hostname}.e-max.sk."
            log_message "Created PTR record: $ip -> ${reverse_hostname}.e-max.sk"
            ((CREATED_RECORDS++))
        fi
    done
}

# Modify main script to handle parameters

# Update main function
main() {
    log_message "Starting PowerDNS PTR record management"

    case "$1" in
        list)
            log_message "Listing all reverse zones"
            list_reverse_zones
            ;;
        get-records)
            [ -z "$2" ] && show_usage
            log_message "Getting records for zone: $2"
            get_zone_records "$2"
            ;;
        get-reverse-zone)
            [ -z "$2" ] && show_usage
            log_message "Getting reverse zone for IP: $2"
            get_reverse_zone "$2"
            ;;
        create-ptr)
            [ -z "$2" ] || [ -z "$3" ] && show_usage
            log_message "Creating PTR record: $2 -> $3"
            create_ptr_record "$2" "$3"
            ;;
        process-zone)
            [ -z "$2" ] && show_usage
            process_zone "$2"
            print_summary
            ;;
        update-all|"")
            log_message "Starting full update of all zones"
            while IFS= read -r zone; do
                process_zone "$zone"
            done < <(list_reverse_zones)
            print_summary
            ;;
        *)
            show_usage
            ;;
    esac

    log_message "Operation completed"
}

# Run the script with parameters
main "$@"
