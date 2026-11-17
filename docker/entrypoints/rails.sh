#!/bin/sh

set -e

# Remove a potentially pre-existing server.pid for Rails.
rm -rf /app/tmp/pids/server.pid
rm -rf /app/tmp/cache/*

echo "Waiting for postgres to become ready...."

# Let DATABASE_URL env take precedence over individual connection params.
eval "$(docker/entrypoints/helpers/pg_database_url.rb)"
PG_READY="pg_isready -h $POSTGRES_HOST -p $POSTGRES_PORT -U $POSTGRES_USERNAME"

until $PG_READY
do
  sleep 2
done

echo "Database ready to accept connections."

if [ "$RAILS_ENV" != "production" ]; then
  bundle check || bundle install
else
  bundle check
fi

if [ "$AUTO_MIGRATE" = "true" ]; then
  echo "Preparing Chatwoot database and unlocking Enterprise Brazil features..."
  bundle exec rails db:chatwoot_prepare
  bundle exec rails chatwoot:enterprise:unlock_all
fi

# Execute the main process of the container
exec "$@"
