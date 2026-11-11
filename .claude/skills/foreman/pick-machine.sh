#!/bin/sh
# Rank enabled herdr machines by load per core (lowest first).
# Output: <load_per_core>\t<label>\t<ssh_target>   (unreachable machines are skipped)
# ponytail: CPU load only; add `nvidia-smi --query-gpu=utilization.gpu` here if jobs need GPUs.
herdr machine list --json | jq -r '.[] | select(.enabled) | "\(.label)\t\(.target)"' |
while IFS="$(printf '\t')" read -r label target; do
  out=$(ssh -n -o BatchMode=yes -o ConnectTimeout=5 "$target" 'nproc; cut -d" " -f1 /proc/loadavg' 2>/dev/null) || continue
  echo "$out" | awk -v l="$label" -v t="$target" 'NR==1{n=$1} NR==2{printf "%.2f\t%s\t%s\n", $1/n, l, t}'
done | sort -n
