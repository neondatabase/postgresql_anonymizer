#!/bin/sh

set -e

echo "shared_preload_libraries = 'anon'" >> /var/lib/postgresql/data/postgresql.conf

