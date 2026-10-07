#!/usr/bin/env bash
# Status line: model · ctx % (used/size) · $cost · git branch. Missing parts are omitted.
input=$(cat)
command -v jq >/dev/null 2>&1 || exit 0

q() { printf '%s' "$input" | jq -r "$1" 2>/dev/null; }

model=$(q '.model.display_name // empty')

# Context: a 10-cell bar coloured green / yellow / red as it fills, then percent and
# tokens used / window size, abbreviated as e.g. 84k.
read -r pct used size < <(q 'def k: if . >= 1000 then "\(. / 1000 | round)k" else "\(.)" end;
  if .context_window.used_percentage != null and .context_window.context_window_size != null
  then "\(.context_window.used_percentage | round) \(.context_window.total_input_tokens // 0 | k) \(.context_window.context_window_size | k)"
  else empty end')
ctx=""
if [ -n "$pct" ]; then
  filled=$(( (pct + 5) / 10 )); (( filled > 10 )) && filled=10
  if (( pct < 50 )); then color=32; elif (( pct < 80 )); then color=33; else color=31; fi
  bar=""
  for ((i = 0; i < 10; i++)); do (( i < filled )) && bar+="█" || bar+="░"; done
  ctx=$(printf '\033[%sm%s\033[0m %s%% (%s/%s)' "$color" "$bar" "$pct" "$used" "$size")
fi

cost=$(q '.cost.total_cost_usd // empty')
[ -n "$cost" ] && cost=$(printf '$%.2f' "$cost" 2>/dev/null)

dir=$(q '.workspace.current_dir // .cwd // empty')
branch=""
[ -n "$dir" ] && branch=$(git -C "$dir" --no-optional-locks symbolic-ref --short -q HEAD 2>/dev/null)

out=""
for part in "$model" "$ctx" "$cost" "$branch"; do
  [ -n "$part" ] && out="${out:+$out · }$part"
done
printf '%s\n' "$out"
