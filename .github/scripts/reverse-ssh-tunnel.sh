#!/bin/bash

set -eu

# Some constants
loglevel_info=5
loglevel_debug=4

# Defaults - override if necessary
: ${REVERSE_SSH_SLEEPTIME:=21600} # Max time until a GitHub Action runner times out
: ${REVERSE_SSH_REMOTE_PORT:=32022}
: ${REVERSE_SSH_VERBOSE:=""}
: ${REVERSE_SSH_LOGLEVEL:=${loglevel_info}}

# This should be inherited from the runner
: ${TMPDIR="/tmp"}
: ${USER:="$(id -un)"}

die() {
  local l_exitcode=${1}
  shift

  echo "${@}" >&2
  exit ${l_exitcode}
}

log() {
  local l_loglevel=${1}
  shift

  if test "${l_loglevel}" -ge "${REVERSE_SSH_LOGLEVEL}"; then
    echo "${@}"
  fi
}

ssh_private_keyfile=$(mktemp -q ${TMPDIR}/ssh-key-XXXXXX)
trap "/bin/rm -f ${ssh_private_keyfile}" 0 1 2 3 5 6 12 13 14 15

set +u
test -n "${REVERSE_SSH_HOST}" || die 1 "Environment variable 'REVERSE_SSH_HOST' must be provided"
test -n "${REVERSE_SSH_PRIVATE_KEY}" || die 1 "Environment variable 'REVERSE_SSH_PRIVATE_KEY' must be provided"
test -n "${REVERSE_SSH_PUBLIC_KEY}" || die 1 "Environment variable 'REVERSE_SSH_PUBLIC_KEY' must be provided"
set -u

echo "${REVERSE_SSH_PRIVATE_KEY}" >${ssh_private_keyfile}

# enable reverse login
mkdir -p $HOME/.ssh
echo "${REVERSE_SSH_PUBLIC_KEY}" >>${HOME}/.ssh/authorized_keys
chmod 755 $HOME
chmod 700 $HOME/.ssh
chmod 600 $HOME/.ssh/authorized_keys
# If all else fails login via password
# echo "runner:runner" | sudo -E chpasswd

# Don't forward any inherited agent authentication
unset SSH_AUTH_SOCK

log ${loglevel_info} "You should soon be able to log on '${REVERSE_SSH_HOST}' via 'ssh -o StrictHostKeyChecking=no -p ${REVERSE_SSH_REMOTE_PORT} ${USER}@localhost'"

set +e
ssh \
  -o StrictHostKeyChecking=no \
  -i ${ssh_private_keyfile} \
  ${REVERSE_SSH_VERBOSE} \
  -R ${REVERSE_SSH_REMOTE_PORT}:localhost:22 \
  ${REVERSE_SSH_HOST} \
  sleep ${REVERSE_SSH_SLEEPTIME}

if test "${loglevel_debug}" -ge "${REVERSE_SSH_LOGLEVEL}"; then
  sudo cat /var/log/auth.log
fi
