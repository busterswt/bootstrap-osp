#!/usr/bin/env bash

# Copyright 2021, Rackspace US, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


## Vars ----------------------------------------------------------------------
LINE='----------------------------------------------------------------------'
ANSIBLE_PARAMETERS=${ANSIBLE_PARAMETERS:-""}
STARTTIME="${STARTTIME:-$(date +%s)}"

## Functions -----------------------------------------------------------------

# Determine the distribution we are running on, so that we can configure it
# appropriately.
function determine_distro {
    source /etc/os-release 2>/dev/null
    export DISTRO_ID="${ID}"
    export DISTRO_NAME="${NAME}"
}

function ssh_key_create {
  # Ensure that the ssh key exists and is an authorized_key
  key_path="${HOME}/.ssh"
  key_file="${key_path}/id_rsa"

  # Ensure that the .ssh directory exists and has the right mode
  if [ ! -d ${key_path} ]; then
    mkdir -p ${key_path}
    chmod 700 ${key_path}
  fi

  # Ensure a full keypair exists
  if [ ! -f "${key_file}" -o ! -f "${key_file}.pub" ]; then

    # Regenrate public key if private key exists
    if [ -f "${key_file}" ]; then
      ssh-keygen -f ${key_file} -y > ${key_file}.pub
    fi

    # Delete public key if private key missing
    if [ ! -f "${key_file}" ]; then
      rm -f ${key_file}.pub
    fi

    # Regenerate keypair if both keys missing
    if [ ! -f "${key_file}" -a ! -f "${key_file}.pub" ]; then
      ssh-keygen -t rsa -f ${key_file} -N ''
    fi

  fi

  # Ensure that the public key is included in the authorized_keys
  # for the default root directory and the current home directory
  key_content=$(cat "${key_file}.pub")
  if ! grep -q "${key_content}" ${key_path}/authorized_keys; then
    echo "${key_content}" | tee -a ${key_path}/authorized_keys
  fi
}

function exit_state {
  set +x
  TOTALSECONDS="$(( $(date +%s) - STARTTIME ))"
  info_block "Run Time = ${TOTALSECONDS} seconds || $((TOTALSECONDS / 60)) minutes"
  if [ "${1}" == 0 ];then
    info_block "Status: Success"
  else
    info_block "Status: Failure"
  fi
  exit ${1}
}

function exit_success {
  set +x
  exit_state 0
}

function exit_fail {
  set +x
  log_instance_info
  info_block "Error Info - $@"
  exit_state 1
}

function print_info {
  PROC_NAME="- [ $@ ] -"
  printf "\n%s%s\n" "$PROC_NAME" "${LINE:${#PROC_NAME}}"
}

function info_block {
  echo "${LINE}"
  print_info "$@"
  echo "${LINE}"
}

## Signal traps --------------------------------------------------------------
# Trap all Death Signals and Errors
trap "exit_fail ${LINENO} $? 'Received STOP Signal'" SIGHUP SIGINT SIGTERM
trap "exit_fail ${LINENO} $?" ERR

## Pre-flight check ----------------------------------------------------------
# Make sure only root can run our script
if [ "$(id -u)" != "0" ]; then
  info_block "This script must be run as root"
  exit_state 1
fi

# Check that we are in the root path of the cloned repo
if [ ! -d "etc" -a ! -d "scripts" -a ! -d "playbooks" ]; then
  info_block "** ERROR **"
  echo "Please execute this script from the root directory of the cloned source code."
  echo -e "Example: /opt/bootstrap-osp/\n"
  exit_state 1
fi


## Exports -------------------------------------------------------------------
# Export known paths
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:${PATH}"

# Export the home directory just in case it's not set
export HOME="/root"
