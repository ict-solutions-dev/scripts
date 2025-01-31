#!/bin/bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Table formatting
TABLE_WIDTH=100

truncate_text() {
    local str="$1"
    local width="$2"
    if [ ${#str} -gt $width ]; then
        echo "${str:0:$((width-3))}..."
    else
        printf "%-${width}s" "$str"
    fi
}

draw_line() {
    printf "+-%-30s-+-%-25s-+-%-20s-+-%-15s-+\n" \
        $(printf '%0.s-' {1..30}) \
        $(printf '%0.s-' {1..25}) \
        $(printf '%0.s-' {1..20}) \
        $(printf '%0.s-' {1..15})
}

print_row() {
    local col1="$1"
    local col2="$2"
    local col3="$3"
    local col4="$4"

    printf "| %-30.30s | %-25.25s | %-20.20s | %-15.15s |\n" \
        "${col1:0:30}" \
        "${col2:0:25}" \
        "${col3:0:20}" \
        "${col4:0:15}"
}

print_header() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    printf "${BLUE}%*s${NC}\n" $(((${#1}+$(tput cols))/2)) "$1"
    printf "${CYAN}%*s${NC}\n" $(((${#timestamp}+$(tput cols))/2)) "$timestamp"
}

check_docker() {
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}Docker is not installed${NC}"
        exit 1
    fi
}

show_node_status() {
    print_header "${NODE_EMOJI} NODE STATUS"
    printf "\n"
    draw_line
    print_row "HOSTNAME" "STATUS" "AVAILABILITY" "ROLE"
    draw_line

    docker node ls --format '{{.Hostname}}\t{{.Status}}\t{{.Availability}}\t{{.ManagerStatus}}' | \
    while IFS=$'\t' read -r hostname status availability manager; do
        local status_icon="${READY_EMOJI}"
        [ "$status" != "Ready" ] && status_icon="${ERROR_EMOJI}"
        local role_icon="${WORKER_EMOJI}"
        [ ! -z "$manager" ] && role_icon="${MANAGER_EMOJI}"
        print_row "${hostname}" "${status_icon} ${status}" "$availability" "${role_icon} ${manager:-Worker}"
    done
    draw_line
}

show_services() {
    print_header "SERVICES"
    printf "\n"
    draw_line
    print_row "NAME" "REPLICAS" "IMAGE" "PORTS"
    draw_line

    docker service ls --format '{{.Name}}\t{{.Replicas}}\t{{.Image}}\t{{.Ports}}' | \
    while IFS=$'\t' read -r name replicas image ports; do
        print_row "$name" "$replicas" "$image" "$ports"
    done
    draw_line
}

show_containers() {
    print_header "CONTAINERS PER NODE"
    printf "\n"

    for node in $(docker node ls -q); do
        NODE_NAME=$(docker node inspect $node --format '{{.Description.Hostname}}')
        echo -e "${YELLOW}Node: ${NC}$NODE_NAME"

        draw_line
        print_row "NAME" "IMAGE" "STATE" "PORTS"
        draw_line

        docker node ps $node --format '{{.Name}}\t{{.Image}}\t{{.CurrentState}}\t{{.Ports}}' | \
        while IFS=$'\t' read -r name image state ports; do
            print_row "$name" "$image" "$state" "$ports"
        done
        draw_line
        echo
    done
}

show_resources() {
    print_header "RESOURCE USAGE"
    printf "\n"
    draw_line
    print_row "NODE" "CPU CORES" "MEMORY (GB)" ""
    draw_line

    for node in $(docker node ls -q); do
        NODE_NAME=$(docker node inspect $node --format '{{.Description.Hostname}}')

        CPU=$(docker node inspect $node --format '{{.Description.Resources.NanoCPUs}}')
        if [ ! -z "$CPU" ]; then
            CPU_CORES=$((CPU/1000000000))
        else
            CPU_CORES="N/A"
        fi

        MEM=$(docker node inspect $node --format '{{.Description.Resources.MemoryBytes}}')
        if [ ! -z "$MEM" ] && [ "$MEM" != "0" ]; then
            MEM_GB=$(awk "BEGIN {printf \"%.2f\", $MEM/1024/1024/1024}")
        else
            MEM_GB="N/A"
        fi

        print_row "$NODE_NAME" "$CPU_CORES" "${MEM_GB}GB" ""
    done
    draw_line
}

main() {
    check_docker

    while true; do
        clear
        print_header "DOCKER SWARM MONITOR"
        printf "\n"

        show_node_status
        printf "\n"
        show_services
        printf "\n"
        show_containers
        printf "\n"
        show_resources

        echo -e "\nPress Ctrl+C to exit. Refreshing in 10s..."
        sleep 10
    done
}

main
