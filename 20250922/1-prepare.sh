#!/bin/bash
set -e

MIRROR_DATE="20250922"

confirm() {
  local answer
  read -e -p "$1 [y/N] " answer
  [[ x"$answer" == x"y" || x"$answer" == x"Y" ]]
}

read_partition() {
  local prompt="$1" var="$2" dev
  while true; do
    read -e -p "$prompt" dev
    [ -n "$dev" ] || { echo "  Empty input, please try again." >&2; continue; }
    case "$dev" in
      /dev/*) ;;
      *) echo "  \"$dev\" is not a /dev/ device path." >&2; continue ;;
    esac
    [ -b "$dev" ] || { echo "  \"$dev\" is not a block device." >&2; continue; }
    eval "$var=\"\$dev\""
    return 0
  done
}

confirm "The script should be executed after disk partitioning. Continue?" || exit 0

read_partition "Enter the root partition (e.g. /dev/sda2): " ROOT_PARTITION
mount -v "$ROOT_PARTITION" /mnt

read_partition "Enter the EFI partition (e.g. /dev/sda1): " EFI_PARTITION
mkdir -p /mnt/boot/efi
mount -v "$EFI_PARTITION" /mnt/boot/efi

read_partition "Enter the mirror partition (e.g. /dev/sda3): " MIRROR_PARTITION
mkdir -p /mirror /mnt/mirror
mount -v "$MIRROR_PARTITION" /mirror
mount -v "$MIRROR_PARTITION" /mnt/mirror

lsblk
read -e -p "Press ENTER to continue..."

cp -v /etc/pacman.conf{,.bak.$(date +%Y%m%d%H%M%S)}
mv -v /etc/pacman.d/mirrorlist{,.bak.$(date +%Y%m%d%H%M%S)}
sed -i "s?^SigLevel *= *Required DatabaseOptional?SigLevel = Never?g" /etc/pacman.conf
echo "Server = file:///mirror/archlinux/$MIRROR_DATE/\$repo" > /etc/pacman.d/mirrorlist

pacstrap /mnt base base-devel linux linux-firmware linux-headers man-db amd-ucode intel-ucode

genfstab -U /mnt >> /mnt/etc/fstab
cat /mnt/etc/fstab

mv -v /mnt/etc/pacman.conf{,.bak.$(date +%Y%m%d%H%M%S)}
mv -v /mnt/etc/pacman.d/mirrorlist{,.bak.$(date +%Y%m%d%H%M%S)}
install -Dm644 /etc/pacman.conf -t /mnt/etc
install -Dm644 /etc/pacman.d/mirrorlist -t /mnt/etc/pacman.d
install -Dm644 2-config.sh -t /mnt/root
