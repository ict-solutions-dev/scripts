#!/bin/bash

# Load environment variables from .env file
if [ -f .env ]; then
  export $(cat .env | xargs)
fi

# JSON payload
read -r -d '' PAYLOAD << EOM
{
  "objects": {
    "object": [
      {
        "type": "domain",
        "source": "$SOURCE",
        "attributes": {
          "attribute": [
            {
              "name": "domain",
              "value": "$DOMAIN"
            },
            {
              "name": "descr",
              "value": ""
            },
            {
              "name": "admin-c",
              "value": "$ADMIN_HANDLE"
            },
            {
              "name": "tech-c",
              "value": "$TECH_HANDLE"
            },
            {
              "name": "zone-c",
              "value": "$ZONE_HANDLE"
            },
            {
              "name": "nserver",
              "value": "$NS1"
            },
            {
              "name": "nserver",
              "value": "$NS2"
            },
            {
              "name": "mnt-by",
              "value": "$MAINTAINER_HANDLE"
            },
            {
              "name": "source",
              "value": "$SOURCE"
            }
          ]
        }
      }
    ]
  }
}
EOM

# Make the API request
curl -X POST "$API_URL" \
     -H "Content-Type: application/json" \
     -H "Accept: application/json" \
     -u "$RIPE_USERNAME:$RIPE_PASSWORD" \
     -d "$PAYLOAD"
