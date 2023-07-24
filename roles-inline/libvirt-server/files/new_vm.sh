#!/bin/bash

# some VM hosts have a /storage partition
if [ -d "/storage/cloud-images" ]; then
  image_dir=/storage/cloud-images
else
  image_dir=/srv/cloud-images
fi

if [ -d /storage/libvirt/images ]; then
  target_dir=/var/lib/libvirt/images
else
  target_dir=/var/lib/libvirt/images
fi

# default options
flavor="rocky9"
ram=2
vcpus=1
storage=10
network=54

# display usage
function usage() {
  echo "`basename $0`: Deploy a cloud-init templated libvirt VM."
  echo "Usage:

`basename $0` -h <hostname of VM> [ -f <flavor> -t <network> -i <ip address> ]

where flavor is one of: bionic, focal, jammy, centos7, alma8, rocky8, buster, bullseye (default: ${flavor})
where <ip address> is in x.x.x.x/xx notation (default: dhcp)
and <network> is a VLAN tag of: 1, 50-55 (default: ${network})"

  exit 255
}

function bad_taste() {
  echo "Error: no flavor named ${flavor} -- exiting."
  exit 255
}

# check if tools required by this script are installed
for x in virt-sysprep mcopy virt-install; do
  which ${x} >& /dev/null 
  if [ $? -ne 0 ]; then
    echo "ERROR: Missing ${x} -- please install."
    exit 255
  fi
done

# get command-line args
while getopts "t:h:f:s:p:r:i:mu" OPTION; do
  case $OPTION in
    h) host_name=${OPTARG};;
    f) flavor=${OPTARG};;
    s) storage=${OPTARG};;
    p) vcpus=${OPTARG};;
    r) ram=${OPTARG};;
    i) ipaddr=${OPTARG};;
    m) salted="1";;
    u) update="--update";;
    t) network=${OPTARG};;
    *) usage;;
  esac
done

# make sure we have necessary variables
if [ -z "${host_name}" ]; then
  usage
fi

if [ ${#} -eq 0 ]; then
  usage
fi

# regex to validate network
if [[ ${network} =~ ^(1|5[0-5])$ ]]; then
  echo "Network set to VLAN ID ${network}"
else
  echo "Bad network: ${network}"
  usage
fi

if [ ${network} -eq 1 ]; then
  ifname="br0"
else
  ifname="br-vlan${network}"
fi

# ensure that hostname passed for vlan54 ends in .lab
if [ "${network}" -eq 54 ]; then
  if [[ ${host_name} =~ .lab$ ]]; then
    echo "Hostname ${host_name} validated."
  else
    echo "ERROR: Hostname ${host_name} invalid with vlan id 54."
    usage
  fi
fi

# RAM is tricky, don't let me be stupid and specify more RAM than I have. Capping out at 16.
if [ "${ram}" -gt 16 ]; then
    echo "Um, no, you can't have more than 16GB RAM."
    usage
else
    memory=$((${ram} * 1024))
fi

# turn the flavor variable into a location for images
case ${flavor} in
  bionic) image="${image_dir}/bionic.qcow2"; dlurl="https://cloud-images.ubuntu.com/bionic/current/bionic-server-cloudimg-amd64.img"; variant="ubuntu18.04";;
  focal) image="${image_dir}/focal.qcow2"; dlurl="https://cloud-images.ubuntu.com/focal/current/focal-server-cloudimg-amd64.img"; variant="ubuntu20.04";;
  jammy) image="${image_dir}/jammy.qcow2"; dlurl="https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"; variant="ubuntu22.04";;
  centos7) image="${image_dir}/centos7.qcow2"; dlurl="https://cloud.centos.org/centos/7/images/CentOS-7-x86_64-GenericCloud.qcow2c"; variant="centos7.0";;
  alma8) image="${image_dir}/almalinux8.qcow2"; dlurl="https://repo.almalinux.org/almalinux/8/cloud/x86_64/images/AlmaLinux-8-GenericCloud-latest.x86_64.qcow2"; variant="centos8";;
  alma9) image="${image_dir}/almalinux9.qcow2"; dlurl="https://repo.almalinux.org/almalinux/9/cloud/x86_64/images/AlmaLinux-9-GenericCloud-latest.x86_64.qcow2"; variant="centos8";;
  rocky8) image="${image_dir}/rocky8.qcow2"; dlurl="https://dl.rockylinux.org/pub/rocky/8/images/x86_64/Rocky-8-GenericCloud.latest.x86_64.qcow2"; variant="centos8";;
  rocky9) image="${image_dir}/rocky9.qcow2"; dlurl="https://dl.rockylinux.org/pub/rocky/9/images/x86_64/Rocky-9-GenericCloud.latest.x86_64.qcow2"; variant="rocky9";;
  buster) image="${image_dir}/buster.qcow2"; dlurl="https://cloud.debian.org/images/cloud/buster/latest/debian-10-generic-amd64.qcow2"; variant="debian9";;
  bullseye) image="${image_dir}/bullseye.qcow2"; dlurl="https://cloud.debian.org/images/cloud/bullseye/latest/debian-11-generic-amd64.qcow2"; variant="debian11";;
  bookworm) image="${image_dir}/bookworm.qcow2"; dlurl="https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2"; variant="debian11";;
  *) bad_taste;;
esac

# network needs to be validated - expected to be a valid bridge interface name
test -L /sys/class/net/${ifname}
if [ $? -ne 0 ]; then
  echo "${ifname} for network ${network} is not a valid network interface - exiting."
  exit 255
fi

# variablize (is that a word?) this so I don't have to type it again in this script
disk_image=${target_dir}/${host_name}.qcow2

# I HAVE been known to forget to create a flavor on the VM host (with virt-sysprep), so we should... check that.
test -f ${image}
if [ $? -ne 0 ]; then
  echo "Missing image for ${flavor}, downloading..."
  pushd "${image_dir}"
  if [ $? -eq 0 ]; then
    test -f $(basename ${dlurl})
    if [ $? -ne 0 ]; then
      wget ${dlurl}
      if [ $? -ne 0 ]; then
        echo "Error downloading ${flavor} image -- exiting."
        exit 255
      fi
    fi

    # prep the image we just downloaded
    sudo virt-sysprep -a $(basename ${dlurl}) --network --update --selinux-relabel --install qemu-guest-agent
    if [ $? -ne 0 ]; then
      echo "Error running virt-sysprep -- exiting."
      exit 255
    fi
    mv $(basename ${dlurl}) $(basename ${image})
    echo "Image for ${flavor} prepped."
  else
    echo "Error: unable to access ${image_dir}... exiting."
    exit 255
  fi
  popd
fi

# is this VM already defined on the hypervisor?
test -f /etc/libvirt/qemu/${vmname}.xml
if [ $? -eq 0 ]; then
  echo "VM ${host_name} already defined -- exiting."
  exit 255
fi

# does this disk image already exist? Overwriting a running domain's disk, that's bad news, so don't do it.
test -f ${disk_image}
if [ $? -eq 0 ]; then
  echo "${disk_image} exists already -- exiting."
  exit 255
fi

# does the FQDN resolve and ping?
ping -q -c1 -w1 ${hostname} >& /dev/null
if [ $? -eq 0 ]; then
  echo "Error: ${hostname} is alive and responding to pings. Exiting."
  exit 255
fi

# create a temp dir for user-data and meta-data files
tmpdir=$(mktemp -d)

# for virt-sysprep --copy-in to work correctly, the directory name MUST be nocloud
mkdir ${tmpdir}/nocloud
if [ $? -ne 0 ]; then
  echo "Error creating ${tmpdir}/nocloud -- exiting."
  exit 255
fi

# copy the disk image to the right location, and then resize it
echo "Copying ${image} to ${disk_image} and resizing to ${storage}G..."
sudo cp ${image} ${disk_image} && sudo qemu-img resize ${disk_image} ${storage}G
if [ $? -ne 0 ]; then
  echo "Something went wrong either with copying the image, or resizing it -- exiting."
  exit 255
fi

# create a meta-data file
cat << EOF > ${tmpdir}/nocloud/meta-data
instance-id: 1
local-hostname: ${host_name}
EOF

# create user-data file
cat << EOF > ${tmpdir}/nocloud/user-data
#cloud-config
users:
    - name: root
      plain_text_passwd: resetm3n0w
      lock_passwd: false
      ssh_authorized_keys:
        - ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDJNEonif7PNwf6DFR1/nqU9phsdgGFzSMO8EWkD3caLDoAs8/TvnQ+iwvzcox8yAKpU6uIaungjEil3LdiScQSB6yJXB++/4pO827+8AkYmo3seKWkk7LTpHuW8zPc8dbsre1uBCuV7VoAeMJkml1O4wwYooJVt55Nfj2qwVqbg7EMyO9C0KN6X85GLOV1WI3Oa95gmwJvnhg3sbFFW0l4DddsU7rmqzftHyfNzgg/X7VbBa1GzAhhr+EmCh19r8msAgVj6odKutk9/Z8bvE9kUH1+4c0WkdpeVOkdcacluRFZ3lrb9+UTdZ/H1ebTEKbpp/wg7eGT+pO4JcFNrqSqyiVkcBjYi6u8rzCJ3KjSy9718wwWM+y3m/NW0gCuuKTQnCeNqe+b1SUvvPZqGvMykGxStHszkVSDjuGZlu9IsP59ALSWDOvTkybu+fIONw4EmItrdPmGqGHYuA0tTzwLh4QqPr8fvF8sZaVislzHaPWzwaafKc2QpxjoABpfXdU= xthor@spindel.xthorsworld.com
        - ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBJxAV/7QW6fm8xwV05rDjh9eYZlXW54kBcSgfOVKVOAhSzzuH0+CmkZVL6vCYMBnkjGz/f33mp15WZBx4fjxLrw= default@secretive.spindel.local
    - name: xthor
      shell: /bin/bash
      plain_text_passwd: p@ssw0rd
      lock_passwd: false
      sudo: ALL=(ALL) NOPASSWD:ALL
      ssh_authorized_keys:
        - ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDJNEonif7PNwf6DFR1/nqU9phsdgGFzSMO8EWkD3caLDoAs8/TvnQ+iwvzcox8yAKpU6uIaungjEil3LdiScQSB6yJXB++/4pO827+8AkYmo3seKWkk7LTpHuW8zPc8dbsre1uBCuV7VoAeMJkml1O4wwYooJVt55Nfj2qwVqbg7EMyO9C0KN6X85GLOV1WI3Oa95gmwJvnhg3sbFFW0l4DddsU7rmqzftHyfNzgg/X7VbBa1GzAhhr+EmCh19r8msAgVj6odKutk9/Z8bvE9kUH1+4c0WkdpeVOkdcacluRFZ3lrb9+UTdZ/H1ebTEKbpp/wg7eGT+pO4JcFNrqSqyiVkcBjYi6u8rzCJ3KjSy9718wwWM+y3m/NW0gCuuKTQnCeNqe+b1SUvvPZqGvMykGxStHszkVSDjuGZlu9IsP59ALSWDOvTkybu+fIONw4EmItrdPmGqGHYuA0tTzwLh4QqPr8fvF8sZaVislzHaPWzwaafKc2QpxjoABpfXdU= xthor@spindel.xthorsworld.com
        - ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBJxAV/7QW6fm8xwV05rDjh9eYZlXW54kBcSgfOVKVOAhSzzuH0+CmkZVL6vCYMBnkjGz/f33mp15WZBx4fjxLrw= default@secretive.spindel.local
        - ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBFnnJ8Wl3+F3sSIx7hYhpvwgJnbc9PIym7EufgnlpiOqk5OO6SfjImxvzzt2cEfyK0eTQqb34UZtcSelziATg8M= sekho@secretive.sekho.local
timezone: America/Denver
package_upgrade: true
runcmd:
    - touch /etc/cloud/cloud-init.disabled
EOF

if [ -n "${ipaddr}" ]; then
  # we expect this IP address to be provided in x.x.x.x/xx form
  # TODO: regex to check it
    gateway="10.200.${network}.1"
  if [ ${network} -eq 54 ]; then
    search="xthorsworld.lab"
  else
    search="xthorsworld.com"
  fi

  if [[ "${variant}" == rocky* || "${variant}" == centos* ]]; then
    devname="eth0"
    match="eth"
  else
    devname="enp1s0"
    match="enp"
  fi

  # write out network config
  cat << EOF > ${tmpdir}/nocloud/network-config
version: 2
ethernets:
  ${devname}:
    match:
      name: "${match}*"
    addresses:
    - ${ipaddr}
    gateway4: ${gateway}
    nameservers:
      search: [${search}]
      addresses: [${gateway}]
EOF
fi

# if we don't run virt-sysprep, even if we're not updating, the a new machine seed does not get generated
# this causes issues with debian-based systems, at least, because they boot up and make DHCP requests
# that result in IP conflicts
echo "Running virt-sysprep against ${disk_image} ..."
sudo virt-sysprep -a ${disk_image} --network ${update} --selinux-relabel
if [ $? -ne 0 ]; then
  echo "virt-sysprep exited with a non-zero status -- exiting."
  exit 255
fi

# kick off virt-install
echo "Installing VM ${host_name}..."
sudo virt-install --virt-type kvm --name ${host_name} --ram ${memory} --vcpus ${vcpus} \
  --os-variant ${variant} --network=bridge=${ifname},model=virtio --graphics vnc \
  --disk path=${disk_image},cache=writeback \
  --cloud-init root-password-generate=no,disable=on,user-data=${tmpdir}/nocloud/user-data,meta-data=${tmpdir}/nocloud/meta-data \
  --noautoconsole --import

# cleanup
rm -rf ${tmpdir}

exit 0
