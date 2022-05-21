#!/bin/bash

# rudimentary OS detection
if [ -f /etc/os-release ]; then
    grep -q fedora /etc/os-release
    if [ $? -eq 0 ]; then
        pm=dnf
    fi

    grep -q ubuntu /etc/os-release
    if [ $? -eq 0 ]; then
        pm=apt
    fi

    sudo ${pm} install ansible git
    for i in ansible git; do
        which ${i} >& /dev/null
        if [ $? -ne 0 ]; then
            echo "Error: ${i} not found. Check package management status."
            exit 255
        fi
    done
else
    echo "/etc/os-release not found -- sorry, you'll have to do this manually."
    exit 255
fi

# make sure the SSH key exists
if [ -f .ssh/id_rsa ]; then
    chmod 600 .ssh/id_rsa
    ssh-keygen -y -f .ssh/id_rsa > .ssh/id_rsa.pub
else
    echo "Error: .ssh/id_rsa not found"
    exit 255
fi

# really should merge this to main someday, no?
ansible-pull -U https://github.com/xthor0/ansible.git -K -C debian-openbox playbooks/workstation.yml
