#!/bin/sh
echo "Starting pre-flight check..."

echo -n "Database url: "
if [ -z "$DATABASE_URL" ]; then
    echo "\nYou need to tell me where the database is and how to connect to it by setting DATABASE_URL environment variable"
    echo "e.g.: Using the flag -e DATABASE_URL='mysql://user:pass@127.0.0.1:3306/dbname?charset=utf8mb4&serverVersion=5.7' at docker container run"
    exit 1
fi
# Show DATABASE_URL without password for debugging
DB_URL_SAFE=$(echo "$DATABASE_URL" | sed 's/:[^:@]*@/:***@/g')
echo "Ok - $DB_URL_SAFE"
if echo "$DATABASE_URL" | grep -q "localhost\|127.0.0.1"; then
    echo "WARNING: DATABASE_URL uses localhost/127.0.0.1. In Docker, use 'mysqldb' as hostname instead!"
fi

# Change to application directory
cd /var/www/html || exit 1

echo "Clearing cache..."
php bin/console cache:clear --no-debug --no-warmup || true
php bin/console cache:warmup || true

echo "Waiting for database connection..."
attempt=0

while true; do
    # Try to connect using doctrine:query:sql
    OUTPUT=$(php bin/console -q doctrine:query:sql "SELECT 1" 2>&1)
    EXIT_CODE=$?
    
    if [ $EXIT_CODE -eq 0 ]; then
        echo "Database connection successful!"
        break
    fi
    
    attempt=$((attempt + 1))
    if [ $((attempt % 5)) -eq 0 ]; then
        echo "Waiting for database... (attempt $attempt)"
        if [ -n "$OUTPUT" ]; then
            echo "  Error: $OUTPUT"
        fi
    fi
    sleep 2
done

echo "Database is up, configuring schema"

set -xe

# Install/Updates the database schema
php bin/console novosga:install

echo "Setup done! Starting application"
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf