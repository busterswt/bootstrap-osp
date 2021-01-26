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
#
# (c) 2021, James Denton <james.denton@rackspace.com>

## Shell Opts ----------------------------------------------------------------
set -e -u -x

## Vars ----------------------------------------------------------------------
export HTTP_PROXY=${HTTP_PROXY:-""}
export HTTPS_PROXY=${HTTPS_PROXY:-""}
# The Ansible version used for testing
export ANSIBLE_PACKAGE=${ANSIBLE_PACKAGE:-"ansible-base==2.10.4"}
export SSH_DIR=${SSH_DIR:-"/root/.ssh"}

# Use pip opts to add options to the pip install command.
# This can be used to tell it which index to use, etc.
export PIP_OPTS=${PIP_OPTS:-""}

# This script should be executed from the root directory of the cloned repo
cd "$(dirname "${0}")/.."

## Functions -----------------------------------------------------------------
info_block "Checking for required libraries." 2> /dev/null ||
    source scripts/scripts-library.sh

## Pre-flight check ----------------------------------------------------------
# Make sure only root can run our script
if [ "$(id -u)" != "0" ]; then
  info_block "This script must be run as root"
  exit_state 1
fi

## Main ----------------------------------------------------------------------
info_block "Bootstrapping Baremetal Director Node..."

# Create the ssh dir if needed
ssh_key_create

# Install ansible collections
ansible-galaxy install -r requirements.yml

# Determine the distribution which the host is running on
determine_distro

# Install the base packages
case ${DISTRO_ID} in
    centos|rhel)
        dnf -y group install \
            'Virtualization host' 'Virtualization Client'
        dnf -y update
        ;;
esac

# touch the tmp
touch /tmp/reboot_me

echo "Baremetal Director node bootstrapped. You must REBOOT this node before continuing!"
