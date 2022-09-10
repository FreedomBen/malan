function psql-malan ()
{
  export PGPASSWORD="${DB_PASSWORD}"

  psql \
    -U "${DB_USER}" \
    -h "${DB_HOSTNAME}" \
    -p "${DB_PORT}" \
    -d "${DB_DATABASE}" \
    --set=sslmode=require
}

alias psql='psql-malan'
