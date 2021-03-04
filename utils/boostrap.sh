#!/bin/bash

# objective: install ansible, git, and pull down this repo
# run the playbook and ask for sudo creds (ansible-playbook -K)

if [ -f /etc/os-release ]; then
    grep -q debian /etc/os-release
    if [ $? -eq 0 ]; then
        echo "Installing git & ansible with apt"
        sudo apt update && sudo apt install git ansible
    fi

    grep -q rhel /etc/os-release
    if [ $? -eq 0 ]; then
        echo "Sorry, I don't work with RHEL or derivatives yet."
        exit 255
    fi
else
    echo "Bro, what dis. No /etc/os-release file. I'm done."
    exit 255
fi

# check it out to /tmp
mkdir /tmp/temp_bootstrap && cd /tmp/temp_bootstrap && git clone https://github.com/xthor0/ansible.git

cd ansible

# won't need this after merge to master
git checkout refactor

ansible-playbook -K -i inv/local.hosts playbooks/workstation.yml