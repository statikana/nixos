#!/usr/bin/env bash
mode=$(cat $XDG_RUNTIME_DIR/fan-mode 2>/dev/null || echo auto)

case "$mode" in
    quiet)
        printf '{"text":"󰠝 <span>quiet</span>","class":"quiet"}\n'
        ;;
    auto)
        printf '{"text":"󱜝 <span>auto</span>","class":"auto"}\n'
        ;;
    max)
        printf '{"text":"󱜝 <span>max</span>","class":"max"}\n'
        ;;
    *)
        printf '{"text":"<span>?</span>","class":"unknown"}\n'
        ;;
esac