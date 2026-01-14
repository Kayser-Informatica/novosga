#!/bin/sh
echo "Starting pre-flight check..."

# Change to application directory
cd /var/www/html || exit 1

# Create .env file from environment variables
echo "Creating .env file from environment variables..."
cat > .env <<EOF
APP_ENV=${APP_ENV:-prod}
APP_DEBUG=${APP_DEBUG:-0}
APP_SECRET=${APP_SECRET:-}
DATABASE_URL=${DATABASE_URL:-}
MESSENGER_TRANSPORT_DSN=${MESSENGER_TRANSPORT_DSN:-doctrine://default}
MERCURE_URL=${MERCURE_URL:-}
MERCURE_PUBLIC_URL=${MERCURE_PUBLIC_URL:-}
MERCURE_JWT_SECRET=${MERCURE_JWT_SECRET:-}
OAUTH_PRIVATE_KEY=${OAUTH_PRIVATE_KEY:-}
OAUTH_PUBLIC_KEY=${OAUTH_PUBLIC_KEY:-}
OAUTH_PASSPHRASE=${OAUTH_PASSPHRASE:-}
OAUTH_ENCRYPTION_KEY=${OAUTH_ENCRYPTION_KEY:-}
LANGUAGE=${LANGUAGE:-pt_BR}
NOVOSGA_ADMIN_USERNAME=${NOVOSGA_ADMIN_USERNAME:-admin}
NOVOSGA_ADMIN_PASSWORD=${NOVOSGA_ADMIN_PASSWORD:-123456}
NOVOSGA_ADMIN_FIRSTNAME=${NOVOSGA_ADMIN_FIRSTNAME:-Administrador}
NOVOSGA_ADMIN_LASTNAME=${NOVOSGA_ADMIN_LASTNAME:-Global}
NOVOSGA_UNITY_NAME=${NOVOSGA_UNITY_NAME:-Minha Unidade}
NOVOSGA_UNITY_CODE=${NOVOSGA_UNITY_CODE:-U01}
NOVOSGA_NOPRIORITY_NAME=${NOVOSGA_NOPRIORITY_NAME:-Normal}
NOVOSGA_NOPRIORITY_DESCRIPTION=${NOVOSGA_NOPRIORITY_DESCRIPTION:-Serviço normal}
NOVOSGA_PRIORITY_NAME=${NOVOSGA_PRIORITY_NAME:-Prioridade}
NOVOSGA_PRIORITY_DESCRIPTION=${NOVOSGA_PRIORITY_DESCRIPTION:-Serviço prioritário}
NOVOSGA_PLACE_NAME=${NOVOSGA_PLACE_NAME:-Guichê}
EOF

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