#!/bin/bash

# Load environment variables from .env file
if [ -f .env ]; then
    source .env
else
    echo "Error: .env file not found"
    exit 1
fi

# PowerDNS API configuration with defaults
PDNS_API_URL="${PDNS_API_URL}"
PDNS_API_KEY="${PDNS_API_KEY}"
SERVER_ID="${SERVER_ID:-localhost}"

# Validate required environment variables
if [ -z "$PDNS_API_KEY" ] || [ "$PDNS_API_KEY" = "your-api-key" ]; then
    echo "Error: PDNS_API_KEY not configured in .env file"
    exit 1
fi

# Validate API endpoint
if [[ ! "$PDNS_API_URL" =~ ^https?:// ]]; then
    echo "Error: Invalid PDNS_API_URL format. Must start with http:// or https://"
    exit 1
fi

# Array of zones to exclude
EXCLUDED_ZONES=(
    "64.100.in-addr.arpa."
    "168.237.91.in-addr.arpa."
    "169.237.91.in-addr.arpa."
    "170.237.91.in-addr.arpa."
)

# Add logging configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="${SCRIPT_DIR}/pdns-ptr-update.log"
LOG_DIR="$(dirname "$LOG_FILE")"

# Setup logging directory
if [ ! -d "$LOG_DIR" ]; then
    mkdir -p "$LOG_DIR" || {
        echo "ERROR: Cannot create log directory $LOG_DIR"
        exit 1
    }
fi

if [ ! -w "$LOG_DIR" ]; then
    echo "ERROR: Log directory $LOG_DIR is not writable"
    exit 1
fi

# Initialize counters
PROCESSED_ZONES=0
CREATED_RECORDS=0
SKIPPED_ZONES=0

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

# Function to check curl status
check_curl_status() {
    if [ $? -ne 0 ]; then
        log_message "ERROR: API request failed"
        exit 1
    fi
}

# Function to validate IP address
validate_ip() {
    local ip=$1
    if [[ ! $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        return 1
    fi
    IFS='.' read -r -a octets <<< "$ip"
    for octet in "${octets[@]}"; do
        if [[ $octet -lt 0 || $octet -gt 255 ]]; then
            return 1
        fi
    done
    return 0
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

# Function to convert IP to expected format
format_ip() {
    local ip=$1
    IFS='.' read -r a b c d <<< "$ip"
    echo "${a}-${b}-${c}-${d}"
}

# Function to get reverse zone for an IP
get_reverse_zone() {
    local ip=$1
    if ! validate_ip "$ip"; then
        log_message "ERROR: Invalid IP address format: $ip"
        return 1
    fi
    IFS='.' read -r a b c d <<< "$ip"
    echo "${c}.${b}.${a}.in-addr.arpa."
}

# Function to list all reverse zones
list_reverse_zones() {
    local response=$(curl -s -H "X-API-Key: ${PDNS_API_KEY}" \
        "${PDNS_API_URL}/api/v1/servers/${SERVER_ID}/zones")
    check_curl_status
    echo "$response" | jq -r '.[] | select(.name | endswith(".in-addr.arpa.")) | .name'
}

# Function to get existing PTR records for a zone
get_zone_records() {
    local zone=$1
    local response=$(curl -s -H "X-API-Key: ${PDNS_API_KEY}" \
        "${PDNS_API_URL}/api/v1/servers/${SERVER_ID}/zones/${zone}")
    check_curl_status
    echo "$response" | jq -r '.rrsets[] | select(.type=="PTR") | .name'
}

# Function to create PTR record
create_ptr_record() {
    local ip=$1
    local hostname=$2

    # Ensure hostname ends with a dot
    [[ "${hostname}" != *"." ]] && hostname="${hostname}."

    log_message "Attempting to create PTR record..."
    log_message "Input: IP=$ip, Hostname=$hostname"

    if ! validate_ip "$ip"; then
        log_message "ERROR: Invalid IP address format: $ip"
        return 1
    fi

    local zone=$(get_reverse_zone "$ip")
    log_message "Using reverse zone: $zone"

    IFS='.' read -r a b c d <<< "$ip"
    local ptr_name="${d}.${zone}"
    # Ensure PTR name ends with a dot
    [[ "${ptr_name}" != *"." ]] && ptr_name="${ptr_name}."

    log_message "Creating PTR record with name: ${ptr_name}"

    local json_data="{
        \"rrsets\": [{
            \"name\": \"${ptr_name}\",
            \"type\": \"PTR\",
            \"ttl\": 3600,
            \"changetype\": \"REPLACE\",
            \"records\": [{
                \"content\": \"${hostname}\",
                \"disabled\": false
            }]
        }]
    }"

    log_message "Sending API request to PowerDNS..."
    local response=$(curl -s -X PATCH -H "X-API-Key: ${PDNS_API_KEY}" \
         -H "Content-Type: application/json" \
         -d "${json_data}" \
         "${PDNS_API_URL}/api/v1/servers/${SERVER_ID}/zones/${zone}")

    if check_curl_status; then
        log_message "Successfully created PTR record for ${ip} -> ${hostname}"
    else
        log_message "ERROR: Failed to create PTR record. API response: $response"
    fi

    echo "$response"
}

# Function to log messages
log_message() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] $1" | tee -a "$LOG_FILE"
}

# Function to print summary
print_summary() {
    log_message "=== Summary ==="
    log_message "Processed zones: $PROCESSED_ZONES"
    log_message "Created PTR records: $CREATED_RECORDS"
    log_message "Skipped zones: $SKIPPED_ZONES"
    log_message "=============="
}

# Function to process zone
process_zone() {
    local zone=$1

    if is_excluded_zone "$zone"; then
        log_message "Skipping excluded zone: $zone"
        ((SKIPPED_ZONES++))
        return
    fi

    log_message "Processing zone: $zone"
    ((PROCESSED_ZONES++))

    local network_parts=($(echo "${zone%%.in-addr.arpa.}" | tr '.' '\n' | awk '{a[i++]=$0} END {for (j=i-1; j>=0;) print a[j--]}' | tr '\n' ' '))
    local network_prefix="${network_parts[0]}.${network_parts[1]}.${network_parts[2]}"

    # Get all existing PTR records for the zone with their content
    local existing_records=$(curl -s -H "X-API-Key: ${PDNS_API_KEY}" \
        "${PDNS_API_URL}/api/v1/servers/${SERVER_ID}/zones/${zone}" | \
        jq -r '.rrsets[] | select(.type=="PTR") | [.name, (.records[0].content // "null")] | @tsv')

    for i in {0..255}; do
        local ip="${network_prefix}.$i"
        local ptr_name="${i}.${zone}."

        # Check if this IP already has a PTR record
        if ! echo "$existing_records" | grep -q "^${ptr_name}"$'\t'; then
            log_message "Adding missing PTR record for $ip"
            local reverse_hostname="host-$(format_ip "$ip")"
            create_ptr_record "$ip" "${reverse_hostname}.e-max.sk."
            log_message "Created PTR record: $ip -> ${reverse_hostname}.e-max.sk"
            ((CREATED_RECORDS++))
        else
            log_message "Skipping $ip - PTR record already exists"
        fi
    done
}

# Main function
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
