#!/bin/bash

# functions
function bad_taste() {
  echo "Error: no flavor named ${flavor} -- exiting."
  exit 255
}

function usage() {
  echo "`basename $0`: Download and import a cloud-init based image for PVE"
  echo "Usage: $(basename $0) -f <flavor>"
}

# check if tools required by this script are installed
for x in axel; do
  which ${x} >& /dev/null 
  if [ $? -ne 0 ]; then
    echo "ERROR: Missing ${x} -- please install."
    exit 255
  fi
done

# get command-line args
while getopts "f:s:" OPTION; do
  case $OPTION in
    f) flavor=${OPTARG};;
    s) storage=${OPTARG};;
    *) usage;;
  esac
done

# validate arguments
if [[ -z ${flavor} || -z ${storage} ]]; then
  echo 'one or more variables are undefined'
  usage
  exit 1
fi

# create temp dir
tmpdir=$(mktemp -d)
if [ $? -ne 0 ]; then
  echo "Could not run mktemp -d -- exiting."
  exit 255
fi

# turn the flavor variable into a location for images
case ${flavor} in
  bionic) image="${tmpdir}/bionic.qcow2"; dlurl="https://cloud-images.ubuntu.com/bionic/current/bionic-server-cloudimg-amd64.img"; vmname=ubuntu1804-tmpl;;
  focal) image="${tmpdir}/focal.qcow2"; dlurl="https://cloud-images.ubuntu.com/focal/current/focal-server-cloudimg-amd64.img"; vmname=ubuntu2004-tmpl;;
  jammy) image="${tmpdir}/jammy.qcow2"; dlurl="https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"; vmname=ubuntu2204-tmpl;;
  noble) image="${tmpdir}/noble.qcow2"; dlurl="https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"; vmname=ubuntu2404-tmpl;;
  centos7) image="${tmpdir}/centos7.qcow2"; dlurl="https://cloud.centos.org/centos/7/images/CentOS-7-x86_64-GenericCloud.qcow2c"; vmname=centos7-tmpl;;
  alma8) image="${tmpdir}/almalinux8.qcow2"; dlurl="https://repo.almalinux.org/almalinux/8/cloud/x86_64/images/AlmaLinux-8-GenericCloud-latest.x86_64.qcow2"; vmname=almalinux8-tmpl;;
  alma9) image="${tmpdir}/almalinux9.qcow2"; dlurl="https://repo.almalinux.org/almalinux/9/cloud/x86_64/images/AlmaLinux-9-GenericCloud-latest.x86_64.qcow2"; vmname=almalinux9-tmpl;;
  rocky8) image="${tmpdir}/rocky8.qcow2"; dlurl="https://dl.rockylinux.org/pub/rocky/8/images/x86_64/Rocky-8-GenericCloud.latest.x86_64.qcow2"; vmname=rocky8-tmpl;;
  rocky9) image="${tmpdir}/rocky9.qcow2"; dlurl="https://dl.rockylinux.org/pub/rocky/9/images/x86_64/Rocky-9-GenericCloud.latest.x86_64.qcow2"; vmname=rocky9-tmpl;;
  buster) image="${tmpdir}/buster.qcow2"; dlurl="https://cloud.debian.org/images/cloud/buster/latest/debian-10-generic-amd64.qcow2"; vmname=debian10-tmpl;;
  bullseye) image="${tmpdir}/bullseye.qcow2"; dlurl="https://cloud.debian.org/images/cloud/bullseye/latest/debian-11-generic-amd64.qcow2"; vmname=debian11-tmpl;;
  bookworm) image="${tmpdir}/bookworm.qcow2"; dlurl="https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2"; vmname=debian12-tmpl;;
  f40) image="${tmpdir}/fedora40.qcow2"; dlurl="https://dl.fedoraproject.org/pub/fedora/linux/releases/40/Cloud/x86_64/images/Fedora-Cloud-Base-Generic.x86_64-40-1.14.qcow2"; vmname=fedora40-tmpl;;
  *) bad_taste;;
esac

# immediately exit on any error (from here)
set -e

# I store my templates starting at 9000 - get the next higest ID
highest_id=$(qm list | awk '{ print $1 }' | grep -v ^VMID | grep -v ^1[0-9][0-9] | sort -n | tail -n1)

# determine which VM ID we should use
if [ -z "${highest_id}" ]; then
  vm_id=9000
else
  vm_id=$((highest_id+1))
fi

echo "Creating VM with ID: ${vm_id}"

# check storage arg
pvesm list ${storage}

# change working dir to tmpdir
pushd ${tmpdir}

# create sshkeys file
cat << EOF > sshkeys
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDJNEonif7PNwf6DFR1/nqU9phsdgGFzSMO8EWkD3caLDoAs8/TvnQ+iwvzcox8yAKpU6uIaungjEil3LdiScQSB6yJXB++/4pO827+8AkYmo3seKWkk7LTpHuW8zPc8dbsre1uBCuV7VoAeMJkml1O4wwYooJVt55Nfj2qwVqbg7EMyO9C0KN6X85GLOV1WI3Oa95gmwJvnhg3sbFFW0l4DddsU7rmqzftHyfNzgg/X7VbBa1GzAhhr+EmCh19r8msAgVj6odKutk9/Z8bvE9kUH1+4c0WkdpeVOkdcacluRFZ3lrb9+UTdZ/H1ebTEKbpp/wg7eGT+pO4JcFNrqSqyiVkcBjYi6u8rzCJ3KjSy9718wwWM+y3m/NW0gCuuKTQnCeNqe+b1SUvvPZqGvMykGxStHszkVSDjuGZlu9IsP59ALSWDOvTkybu+fIONw4EmItrdPmGqGHYuA0tTzwLh4QqPr8fvF8sZaVislzHaPWzwaafKc2QpxjoABpfXdU= linux
ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBHd8PMFpRbXMohUHJqvJmaFyF/JZHyHajm7kyDuQ7tJx5EkdqSFJI9lgLG5m9UWj8x33AUUqbktgnwXx+Y2CK4s= macstudio
ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBK3iRP3Unzjkv8+WvKQyaJCtEAAnC8jPjYqv/H4gSpu/nlhLweTW5LStsolj/Dbiya5nzZDkHI5HRSRhlIFx4Vw= mba15
EOF

# download the source disk
axel -a ${dlurl}
mv $(basename ${dlurl}) $(basename ${image})
#virt-sysprep -a ${image} --selinux-relabel --network --update --install qemu-guest-agent --operations -machine-id

# create the VM
qm create ${vm_id} --name ${vmname} --memory 2048 --net0 virtio,bridge=vmbr0,tag=54 --agent enabled=1 --cpu x86-64-v3 --vga qxl

# import the debian 12 qcow2 disk to VM created
qm importdisk ${vm_id} ${image} ${storage}

# attach disk
qm set ${vm_id} --scsihw virtio-scsi-pci --scsi0 ${storage}:vm-${vm_id}-disk-0

# create ide for cloudinit
qm set ${vm_id} --ide2 ${storage}:cloudinit

# adjust boot settings, otherwise... won't work
qm set ${vm_id} --boot c --bootdisk scsi0
#qm set ${vm_id} --serial0 socket --vga serial0
qm set ${vm_id} --ipconfig0 ip=dhcp

# make the template disk 10G instead of 2G
qm resize ${vm_id} scsi0 10G

# convert VM to a template
qm template ${vm_id}

# set up cloudinit
qm set ${vm_id} --ciuser xthor
qm set ${vm_id} --cipassword p@ssw0rd
qm set ${vm_id} --sshkeys sshkeys
qm set ${vm_id} --cicustom "vendor=local:snippets/vendor.yaml"

# cleanup
rm -rf ${tmpdir}

# done
exit 0
