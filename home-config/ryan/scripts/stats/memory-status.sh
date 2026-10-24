#!/usr/bin/env bash
# Stylized Catppuccin Mocha Memory & Swap status & Pango tooltip for Waybar

read -r mem_total_kb mem_avail_kb mem_buf_kb mem_cached_kb mem_srec_kb swap_total_kb swap_free_kb < <(
    awk '
        /^MemTotal:/     { mt = $2 }
        /^MemAvailable:/ { ma = $2 }
        /^Buffers:/      { mb = $2 }
        /^Cached:/       { mc = $2 }
        /^SReclaimable:/ { ms = $2 }
        /^SwapTotal:/    { st = $2 }
        /^SwapFree:/     { sf = $2 }
        END { printf "%d %d %d %d %d %d %d", mt, ma, mb, mc, ms, st, sf }
    ' /proc/meminfo
)

mem_used_kb=$((mem_total_kb - mem_avail_kb))
mem_cache_kb=$((mem_buf_kb + mem_cached_kb + mem_srec_kb))
swap_used_kb=$((swap_total_kb - swap_free_kb))

pct=$((100 * mem_used_kb / (mem_total_kb > 0 ? mem_total_kb : 1)))
swap_pct=$((swap_total_kb > 0 ? (100 * swap_used_kb / swap_total_kb) : 0))

read -r used_gib total_gib avail_gib cache_gib swap_used_gib swap_total_gib < <(
    awk -v u="$mem_used_kb" -v t="$mem_total_kb" -v a="$mem_avail_kb" -v c="$mem_cache_kb" -v su="$swap_used_kb" -v st="$swap_total_kb" '
    BEGIN {
        printf "%.1f %.1f %.1f %.1f %.1f %.1f",
            u/1048576, t/1048576, a/1048576, c/1048576, su/1048576, st/1048576
    }'
)

make_bar() {
    local p="$1" col="$2" len=12
    local fill=$(( (p * len + 50) / 100 ))
    [ "$fill" -gt "$len" ] && fill="$len"
    local emp=$((len - fill))
    local fs="" es="" i
    for ((i=0; i<fill; i++)); do fs+="━"; done
    for ((i=0; i<emp; i++)); do es+="─"; done
    printf "<span foreground='%s'>%s</span><span foreground='#45475a'>%s</span>" "$col" "$fs" "$es"
}

if [ "$pct" -ge 85 ]; then
    m_col="#f38ba8"
    cls="critical"
elif [ "$pct" -ge 65 ]; then
    m_col="#f9e2af"
    cls="warning"
else
    m_col="#cba6f7"
    cls="normal"
fi

ram_bar=$(make_bar "$pct" "$m_col")
swap_bar=$(make_bar "$swap_pct" "#94e2d5")

# Top 4 memory processes by RSS (rss first so process names with spaces parse cleanly)
top_mem=$(ps -eo rss=,comm= --sort=-rss 2>/dev/null | head -n 4 | awk '{
    rss = $1; $1 = ""; sub(/^[ \t]+/, "", $0);
    name = substr($0, 1, 18);
    gsub(/&/, "&amp;", name); gsub(/</, "&lt;", name); gsub(/>/, "&gt;", name); gsub(/"/, "", name);
    gib = rss / 1048576
    if (gib >= 1.0)
        printf "  <span foreground=\x27#cdd6f4\x27>%-18s</span> <span foreground=\x27#cba6f7\x27 weight=\x27bold\x27>%5.2f GiB</span>\\n", name, gib
    else
        printf "  <span foreground=\x27#cdd6f4\x27>%-18s</span> <span foreground=\x27#a6adc8\x27>%5.0f MiB</span>\\n", name, rss / 1024
}')

tt="<span foreground='#cba6f7' weight='bold'>󰍛  System Memory &amp; Swap</span>\n"
tt+="<span foreground='#45475a'>────────────────────────────────────────────</span>\n"
tt+="  RAM Used:      ${ram_bar}  <span foreground='${m_col}' weight='bold'>${used_gib} GiB</span> <span foreground='#6c7086'>/ ${total_gib} GiB (${pct}%)</span>\n"
tt+="  Available:     <span foreground='#a6e3a1' weight='bold'>${avail_gib} GiB</span>  <span foreground='#6c7086'>·</span>  Page Cache: <span foreground='#cba6f7'>${cache_gib} GiB</span>\n"
tt+="  Swap Space:    ${swap_bar}  <span foreground='#94e2d5' weight='bold'>${swap_used_gib} GiB</span> <span foreground='#6c7086'>/ ${swap_total_gib} GiB (${swap_pct}%)</span>\n"
tt+="\n<span foreground='#74c7ec' weight='bold'>── Top Memory Consumers ────────────────────</span>\n"
tt+="${top_mem}"
tt+="<span foreground='#6c7086'><i>Left-click: Hardware &amp; Temps TUI  ·  Right-click: btop</i></span>"

printf '{"text":"󰍛 %2d%%","class":"%s","tooltip":"%s"}\n' "$pct" "$cls" "$tt"
