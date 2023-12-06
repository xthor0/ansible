# Ben's Ansible Stuff

As I've been learning Ansible, I decided to take a stab at setting up some tasks and playbooks to automate my workstation setup.

## Playbooks

`playbooks/workstation.yml` -- a set of tasks for configuring a GNOME workstation

`playbooks/openbox-workstation.yml` -- same thing, but for OpenBox, which I have some weird fascination with. I love that it is so minimal and stripped down, and I can make it look however I want.

## Setup

Basic instructions:

- Install the base OS (I've tested on Fedora, Rocky Linux, Ubuntu, and Linux Mint)
- install `ansible` and `git`
  - get the ansible PPA for Ubuntu flavors: https://launchpad.net/~ansible/+archive/ubuntu/ansible
- On my personal workstation, copy over SSH keys and load them: `eval $(ssh-agent) && ssh-add`
- Clone this git repo and cd to the directory
- Install the role dependencies: `ansible-galaxy install -r requirements/workstation.yaml`
- Run the playbook: `ansible-pull -U https://github.com/xthor0/ansible.git -K playbooks/workstation.yml`

Also, when testing, I learned that I can use `ansible-pull` directly against a branch, which is handy:

`ansible-pull -U https://github.com/xthor0/ansible.git -K -C <git branch> playbooks/workstation.yml`
