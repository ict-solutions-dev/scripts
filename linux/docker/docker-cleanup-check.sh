#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Initialize counters
volume_count=0
image_count=0
network_count=0

# Print timestamp
echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] Starting Docker cleanup check${NC}"

# Find unused volumes
echo -e "\n${YELLOW}Checking for unused volumes:${NC}"
volumes=$(docker volume ls -qf dangling=true)
if [ -z "$volumes" ]; then
    echo "No unused volumes found"
else
    while read -r vol; do
        # Get volume size using docker system df
        size=$(docker system df -v | grep "$vol" | awk '{print $3}')
        echo "- Volume: $vol (Size: $size)"
        ((volume_count++))
    done <<< "$volumes"
fi

# Find dangling images
echo -e "\n${YELLOW}Checking for dangling images:${NC}"
# Get all images used by services
service_images=$(docker service ls --format '{{.Image}}' | sort -u)
# Get all dangling images
images=$(docker images -f "dangling=true" --format "{{.ID}}|{{.Repository}}|{{.Tag}}|{{.Size}}|{{.CreatedAt}}")

if [ -z "$images" ]; then
    echo "No dangling images found"
else
    while IFS='|' read -r id repo tag size created; do
        # Check if image is used by any service
        is_used=false
        for service_image in $service_images; do
            if docker inspect "$id" --format '{{.RepoTags}}' | grep -q "$service_image"; then
                is_used=true
                break
            fi
        done

        if [ "$is_used" = false ]; then
            echo -e "- Image ID: ${RED}$id${NC}"
            echo "  Repository: $repo"
            echo "  Tag: $tag"
            echo "  Size: $size"
            echo "  Created: $created"
            ((image_count++))
        fi
    done <<< "$images"
fi

# Find unused networks
echo -e "\n${YELLOW}Checking for unused networks:${NC}"
networks=$(docker network ls --filter "type=custom" --format "{{.Name}}")
if [ -z "$networks" ]; then
    echo "No unused networks found"
else
    while read -r net; do
        if [ "$(docker network inspect -f '{{.Containers}}' "$net")" = "map[]" ]; then
            echo "- Network: $net"
            ((network_count++))
        fi
    done <<< "$networks"
fi

# Print summary
echo -e "\n${GREEN}Summary:${NC}"
echo "Found $volume_count unused volumes"
echo "Found $image_count dangling images"
echo "Found $network_count unused networks"
