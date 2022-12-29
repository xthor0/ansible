# Ben's Ansible Stuff

As I've been learning Ansible, I decided to take a stab at setting up some tasks and playbooks to automate my workstation setup.

## Playbooks

`playbooks/workstation.yml` -- a set of tasks for configuring a GNOME workstation

`playbooks/openbox-workstation.yml` -- same thing, but for OpenBox, which I have some weird fascination with. I love that it is so minimal and stripped down, and I can make it look however I want.

## Setup
### GNOME workstation

- Install the base OS (I tested standard installations of both Ubuntu 22.04 and Fedora 37)
- install `ansible` and `git`
- - newer distros will require the `ansible-core` package instead of the `ansible` package (Fedora 36 and above, I think)
- Copy over my SSH keys
- Add the SSH key to the keyring (or the Git repos won't clone): `eval $(ssh-agent) && ssh-add`
- Run the playbook: `ansible-pull -U https://github.com/xthor0/ansible.git -K playbooks/workstation.yml`

Also, when testing, I learned that I can use `ansible-pull` directly against a branch, which is handy:

`ansible-pull -U https://github.com/xthor0/ansible.git -K -C <git branch> playbooks/workstation.yml`

### Openbox workstation

One of the nice things about Openbox is that it's extremely lightweight. While my initial playbook tests were done against the Fedora LXDE spin, or Lubuntu 20.04, I found that I had many packages that I just didn't need. Rather than trying get the playbook to remove them, it was easier to start from a completely minimal installation source, and let the playbook do the rest.

The setup is similar to what's listed for GNOME workstation, except for the installation source:

https://getfedora.org/en/server/download/

Ubuntu is pushing everyone to their new installer, the name of which escapes me. I really had to dig for this:

http://archive.ubuntu.com/ubuntu/dists/focal/main/installer-amd64/current/legacy-images/netboot/mini.iso

For Ubuntu - make no software selection choices.

For Fedora - choose Minimal Install

Then simply run the playbook:

`ansible-pull -U https://github.com/xthor0/ansible.git -K playbooks/openbox-workstation.yml`