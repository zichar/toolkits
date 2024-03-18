#!/bin/bash

set -x

#### --- default params  ---####
DEFAULT_KERNEL=./linux/build/arch/arm64/boot/Image
DEFAULT_BIOS=./uefi/Build/ArmVirtQemu-AARCH64/DEBUG_GCC5/FV/QEMU_EFI.fd
DEFAULT_DTB=./dtb/virt.dtb
#MACHINE_APPEND="iommu=smmuv3,default_bus_bypass_iommu=true"
MACHINE_APPEND="iommu=smmuv3"
MACHINE="-m 512M -smp 2 -cpu cortex-a72 -M virt,${MACHINE_APPEND}"
ROOTFS_BUILDROOT=./rootfs/buildroot-2021.02.5/output/images/rootfs.ext4
ROOTFS_RASPBERRY=./rootfs/raspberry/ubuntu_server/rootfs.img

CMDL_NFSROOT="nfsroot=10.0.2.2:/home/za2068/qemu/rootfs/buildroot-2023.02.9/output/target,nfsvers=4"
CMDLINE="rootwait root=/dev/nfs console=ttyAMA0 earlycon ${CMDL_NFSROOT} rw ip=dhcp"

SSHPORT=2222
NETDEV="-netdev user,id=hostnet0,hostfwd=tcp::${SSHPORT}-:22 -device virtio-net-device,netdev=hostnet0"

GPU="-device virtio-gpu"

#### --- default params  end ---####

ARGS=`getopt -a -o a::d::k::f:g:p:h -l acpi:,dtb:,filesystem:,gdb:,port:,help -- "$@"`
function usage() {
    echo  'help'
}
[ $? -ne 0 ] && usage
#set -- "${ARGS}"
eval set -- "${ARGS}"
while true
do
      case "$1" in
      -a|--acpi)
              if [ -z $2 ]; then
                  BIOS="-bios ${DEFAULT_BIOS}"
              else
                  BIOS="-bios $2"
              fi
              shift
              ;;
      -d|--dtb)
              if [ -z $2 ]; then
                  DTB="-bios ${DEFAULT_DTB}"
              else
                  DTB="-bios $2"
              fi
              shift
              ;;
      -k|--kernel)
              if [ -z $2 ]; then
                  KERNEL=${DEFAULT_KERNEL}
              else
                  KERNEL=$2
              fi
              shift
              ;;
      -f|--filesystem)
              if [ "$2" == "buildroot" ]; then
                  DISK="file=${ROOTFS_BUILDROOT},if=none,index=0,media=disk,format=raw,id=disk0 -device virtio-blk-device,drive=disk0"
                  CMDLINE="rootwait root=/dev/vda console=ttyAMA0 rootfstype=ext4 earlycon nokaslr"
              elif [ "$2" == "raspi" ]; then
                  DISK="file=${ROOTFS_RASPBERRY},if=none,format=raw,id=hd0 -device virtio-blk-device,drive=hd0"
                  CMDLINE="rootwait root=/dev/vda2 console=ttyAMA0 rootfstype=ext4 earlycon nokaslr"
              elif [ "$2" == "nfs" ]; then
                  CMDLINE="rootwait root=/dev/nfs console=ttyAMA0 earlycon nokaslr nfsroot=/home/za2068/nfs/rootfs,nfsvers=4 rw ip=dhcp"
              fi
              shift
              ;;
      -g|--gdb)
              GDB="-S -gdb tcp::${2}"
              shift
              ;;
      -m|--monitor)
              MONITOR="-monitor telnet:127.0.0.1:{$2},server,nowait"
              shift
              ;;
      -p|--port)
              NETDEV="-netdev user,id=hostnet0,hostfwd=tcp::${2}-:22 -device virtio-net-device,netdev=hostnet0"
              shift
              ;;
      -h|--help)
              usage
              ;;
      --)
              shift
              break
              ;;
      esac
shift
done


if [ -z ${KERNEL} ]; then
    KERNEL=${DEFAULT_KERNEL}
fi

if [ -z ${DTB} ]; then
    if [ -z ${BIOS} ]; then
        DTB="-dtb ${DEFAULT_DTB}"
    fi
fi

qemu-system-aarch64 \
    -kernel ${KERNEL} \
    -append "${CMDLINE}" \
    ${BIOS} \
    ${DTB} \
    ${DISK} \
    ${NETDEV} \
    ${MACHINE} \
    ${GDB} \
    ${MONITOR} \
    ${GPU} \
    -nographic
