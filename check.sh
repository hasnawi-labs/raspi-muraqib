#!/bin/sh
# ponytail: one health check, not a test suite
host=${1:-localhost}
# retries so this also works immediately after "docker compose up -d"
curl="curl -fsS --retry 30 --retry-delay 2 --retry-all-errors"
fail=0

check() {
  printf '%-24s' "$1"
  if eval "$2" >/dev/null 2>&1; then echo ok; else echo FAIL; fail=1; fi
}

check "grafana"        "$curl http://$host:3000/api/health"
check "prometheus"     "$curl http://$host:9090/-/healthy"
check "loki"           "$curl http://$host:3100/ready"
check "pi metrics"     "$curl --get --data-urlencode 'query=node_load1' http://$host:9090/api/v1/query | grep -q '\"value\"'"
check "container logs" "$curl http://$host:3100/loki/api/v1/label/job/values | grep -q docker"
check "system logs"    "$curl http://$host:3100/loki/api/v1/label/job/values | grep -q journal"

if [ "$fail" -eq 0 ]; then
  printf '\nall good: http://%s:3000\n' "$host"
else
  printf '\nsomething is down, look at: docker compose ps\n'
fi
exit "$fail"
