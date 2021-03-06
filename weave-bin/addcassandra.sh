#!/bin/sh

. ./env.sh

max=$($docker_cmd ps -a | grep 'cassandra[0-9]\+ *$' | sed 's/.*cassandra\([0-9]\+\).*/\1/' | sort -n | tail -n 1)
num=$($docker_cmd run --rm ubuntu expr $max + 1)

weave run --with-dns \
-d -t \
--privileged \
$dns_search \
--name cassandra${num} -h cassandra${num}.cassandra.local.flyacmeair.net \
acmeair/cassandra
