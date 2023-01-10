# Optimizations

## Things to do

1.  ETS in-memory cache for sessions to avoid lookup.  Alternatively use Redis

## Other considerations

Things that might make the database slow and can be improved:

1.  The API token must be hashed on every request to compare against the hashed one in the database.  If we stop hashing API tokens it will shave quite a bit off of request latency.  Obviously comes with significant security implications.
2.  ToS acceptance have to be validated on every create/update call.  If we stored these in a hash table or something that could improve performance.

