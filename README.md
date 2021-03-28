# Ben's Ansible Stuff

As I've been learning Ansible, I decided to take a stab at setting up some tasks and playbooks to automate my workstation setup.

`playbooks/workstation.yml` -- a set of tasks for configuring a GNOME workstation

`playbooks/openbox-workstation.yml` -- same thing, but for OpenBox, which I have some weird fascination with. I love that it is so minimal and stripped down, and I can make it look however I want.


Ideally, they'll be used with `ansible-pull` so that all I need to do is:

- Install either Fedora Workstation or Ubuntu (tested with both Ubuntu 20.04 and Fedora 33)
- install `ansible` and `git`
- Copy over my SSH keys
- Run the playbook: `ansible-pull -U https://github.com/xthor0/ansible.git -K playbooks/workstation.yml`

Also, when testing, I learned that I can use `ansible-pull` directly against a branch, which is handy:

`ansible-pull -U https://github.com/xthor0/ansible.git -K -C refactor playbooks/workstation.yml`

For the Openbox playbook, I used the LXDE spin of both flavors.