#!/bin/bash
# Parse PostgreSQL connection string and output Goldsky secret JSON
#
# Usage:
#   ./parse-connection-string.sh "postgresql://user:pass@host:5432/dbname"
#   ./parse-connection-string.sh "postgres://user:pass@host/dbname?sslmode=require"
#
# Output: JSON suitable for `goldsky secret create --value`

set -e

CONNECTION_STRING="$1"

if [ -z "$CONNECTION_STRING" ]; then
    echo "Usage: $0 <connection-string>" >&2
    echo "" >&2
    echo "Examples:" >&2
    echo "  $0 'postgresql://user:pass@host:5432/dbname'" >&2
    echo "  $0 'postgres://user:pass@host/dbname?sslmode=require'" >&2
    exit 1
fi

# Remove postgres:// or postgresql:// prefix
CONN="${CONNECTION_STRING#postgresql://}"
CONN="${CONN#postgres://}"

# Remove query string if present (e.g., ?sslmode=require)
CONN="${CONN%%\?*}"

# Extract user:pass@host:port/database
# Pattern: user:password@host:port/database OR user:password@host/database

# Extract credentials (everything before @)
CREDS="${CONN%%@*}"
USER="${CREDS%%:*}"
PASSWORD="${CREDS#*:}"

# Extract host:port/database (everything after @)
HOST_PORT_DB="${CONN#*@}"

# Extract database (everything after /)
DATABASE="${HOST_PORT_DB#*/}"

# Extract host:port (everything before /)
HOST_PORT="${HOST_PORT_DB%%/*}"

# Extract host and port
if [[ "$HOST_PORT" == *":"* ]]; then
    HOST="${HOST_PORT%%:*}"
    PORT="${HOST_PORT#*:}"
else
    HOST="$HOST_PORT"
    PORT="5432"
fi

# Validate extracted values
if [ -z "$USER" ] || [ -z "$PASSWORD" ] || [ -z "$HOST" ] || [ -z "$DATABASE" ]; then
    echo "Error: Could not parse connection string" >&2
    echo "Expected format: postgresql://user:password@host:port/database" >&2
    exit 1
fi

# Output JSON (escape special characters in password for JSON)
# Use jq if available, otherwise use simple output
if command -v jq &> /dev/null; then
    jq -n \
        --arg type "jdbc" \
        --arg protocol "postgres" \
        --arg host "$HOST" \
        --argjson port "$PORT" \
        --arg databaseName "$DATABASE" \
        --arg user "$USER" \
        --arg password "$PASSWORD" \
        '{type: $type, protocol: $protocol, host: $host, port: $port, databaseName: $databaseName, user: $user, password: $password}'
else
    # Escape double quotes and backslashes in password
    ESCAPED_PASSWORD="${PASSWORD//\\/\\\\}"
    ESCAPED_PASSWORD="${ESCAPED_PASSWORD//\"/\\\"}"
    
    cat <<EOF
{"type":"jdbc","protocol":"postgres","host":"$HOST","port":$PORT,"databaseName":"$DATABASE","user":"$USER","password":"$ESCAPED_PASSWORD"}
EOF
fi
