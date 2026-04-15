function psql-malan ()
{
  export PGPASSWORD="${DB_PASSWORD}"

  psql \
    -U "${DB_USERNAME}" \
    -h "${DB_HOSTNAME}" \
    -p "${DB_PORT}" \
    -d "${DB_DATABASE}" \
    --set=sslmode=require
}

alias psql='psql-malan'

function iex-malan ()
{
  iex -S mix run --no-start
}

alias iex='iex-malan'
