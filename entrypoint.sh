#!/usr/bin/env bash

# Inspired by concourse/docker-image-resource:
# https://github.com/concourse/docker-image-resource/blob/master/assets/common.sh

set -o errexit -o pipefail -o nounset -o xtrace

# Stores pid in DOCKERD_PID_FILE (default: /var/run/docker.pid)
DOCKERD_PID_FILE="${DOCKERD_PID_FILE:-/var/run/docker.pid}"
# Logs to DOCKERD_LOG_FILE (default: /var/log/docker.log)
DOCKERD_LOG_FILE="${DOCKERD_LOG_FILE:-/var/log/docker.log}"
# Waits DOCKERD_TIMEOUT seconds for startup and teardown (default: 60)
DOCKERD_TIMEOUT="${DOCKERD_TIMEOUT:-60}"
# Accepts optional DOCKER_OPTS (default: --data-root /scratch/docker)
DOCKER_OPTS="${DOCKER_OPTS:-}"

sanitize_cgroups() {
  mkdir -p /sys/fs/cgroup
  if ! mountpoint -q /sys/fs/cgroup; then
    mount -t tmpfs -o uid=0,gid=0,mode=0755 cgroup /sys/fs/cgroup
  fi
  mount -o remount,rw /sys/fs/cgroup

  sed -e 1d /proc/cgroups | while read sys hierarchy num enabled; do
    if [ "${enabled}" != "1" ]; then
      # subsystem disabled; skip
      continue
    fi

    grouping="$(cat /proc/self/cgroup | cut -d: -f2 | grep "\\<${sys}\\>")"
    if [ -z "${grouping}" ]; then
      # subsystem not mounted anywhere; mount it on its own
      grouping="${sys}"
    fi

    mountpoint="/sys/fs/cgroup/${grouping}"

    mkdir -p "${mountpoint}"

    # clear out existing mount to make sure new one is read-write
    if mountpoint -q "${mountpoint}"; then
      umount "${mountpoint}"
    fi

    mount -n -t cgroup -o "$grouping" cgroup "${mountpoint}"

    if [ "${grouping}" != "${sys}" ]; then
      if [ -L "/sys/fs/cgroup/${sys}" ]; then
        rm "/sys/fs/cgroup/${sys}"
      fi

      ln -s "${mountpoint}" "/sys/fs/cgroup/${sys}"
    fi
  done
}

# Setup container environment and start docker daemon in the background.
start_docker() {
  mkdir -p "$(dirname "${DOCKERD_PID_FILE}")"
  mkdir -p "$(dirname "${DOCKERD_LOG_FILE}")"

  sanitize_cgroups

  # check for /proc/sys being mounted readonly, as systemd does
  if grep '/proc/sys\s\+\w\+\s\+ro,' /proc/mounts >/dev/null; then
    mount -o remount,rw /proc/sys
  fi

  local docker_opts="${DOCKER_OPTS:-}"

  # Pass through `--garden-mtu` from gardian container
  if [[ "${docker_opts}" != *'--mtu'* ]]; then
    local mtu="$(cat /sys/class/net/$(ip route get 8.8.8.8|awk '{ print $5 }')/mtu)"
    docker_opts+=" --mtu ${mtu}"
  fi

  # Use Concourse's scratch volume to bypass the graph filesystem by default
  if [[ "${docker_opts}" != *'--data-root'* ]] && [[ "${docker_opts}" != *'--graph'* ]]; then
    docker_opts+=' --data-root /scratch/docker'
  fi

  dockerd ${docker_opts} --pidfile "${DOCKERD_PID_FILE}" &>"${DOCKERD_LOG_FILE}" &
}

# Wait for docker daemon to be healthy
# Timeout after DOCKERD_TIMEOUT seconds
await_docker() {
  local timeout="${DOCKERD_TIMEOUT}"
  echo "Waiting ${timeout} seconds for Docker to be available"
  local start=${SECONDS}
  (( timeout += start ))
  until docker info &>/dev/null; do
    if (( SECONDS >= timeout )); then
      echo >&2 'Timed out trying to connect to docker daemon.'
      if [[ -f "${DOCKERD_LOG_FILE}" ]]; then
        echo >&2 '---DOCKERD LOGS---'
        cat >&2 "${DOCKERD_LOG_FILE}"
      fi
      exit 1
    fi
    if [[ -f "${DOCKERD_PID_FILE}" ]] && ! kill -0 $(cat "${DOCKERD_PID_FILE}"); then
      echo >&2 'Docker daemon failed to start.'
      if [[ -f "${DOCKERD_LOG_FILE}" ]]; then
        echo >&2 '---DOCKERD LOGS---'
        cat >&2 "${DOCKERD_LOG_FILE}"
      fi
      exit 1
    fi
    sleep 1
  done
  local duration=0
  (( duration = SECONDS - start ))
  echo "Docker available after ${duration} seconds"
}

# Gracefully stop Docker daemon.
# Kill after DOCKERD_TIMEOUT second timeout
stop_docker() {
  local timeout="${DOCKERD_TIMEOUT}"
  if ! [[ -f "${DOCKERD_PID_FILE}" ]]; then
    return 0
  fi
  local docker_pid="$(cat ${DOCKERD_PID_FILE})"
  if [ -z "${docker_pid}" ]; then
    return 0
  fi
  echo "Terminating Docker daemon"
  kill -TERM ${docker_pid}
  echo "Waiting ${timeout} seconds for Docker daemon to exit"
  timeout ${timeout}s wait ${docker_pid}
  if kill -0 ${docker_pid}; then
    echo "Killing Docker daemon"
    kill -9 ${docker_pid}
  fi
}

start_docker
trap stop_docker EXIT
sleep 1
await_docker

# do not exec, because exec disables traps
if [[ "$#" != "0" ]]; then
  "$@"
else
  bash --login
fi
