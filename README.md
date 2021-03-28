# Ben's Ansible Stuff

As I've been learning Ansible, I decided to take a stab at setting up some tasks and playbooks to automate my workstation setup.

`playbooks/workstation.yml` -- a set of tasks for configuring a GNOME workstation

`playbooks/openbox-workstation.yml` -- same thing, but for OpenBox, which I have some weird fascination with. I love that it is so minimal and stripped down, and I can make it look however I want.


Ideally, they'll be used with `ansible-pull` so that all I need to do is:

- install `ansible` and `git` (from default OS sources, tested with both Ubuntu 20.04 and Fedora 33)
- Copy over my SSH keys
- Run the playbook: `ansible-pull -U https://github.com/xthor0/ansible.git -K playbooks/openbox-workstation.yml`

Also, when testing, I learned that I can use `ansible-pull` directly against a branch, which is handy:

`ansible-pull -U https://github.com/xthor0/ansible.git -K -C refactor playbooks/openbox-workstation.yml`