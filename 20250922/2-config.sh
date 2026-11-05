#!/bin/bash
set -e

confirm() {
  local answer
  read -e -p "$1 [y/N] " answer
  [[ x"$answer" == x"y" || x"$answer" == x"Y" ]]
}

read_required() {
  local prompt="$1" var="$2" value
  while true; do
    read -e -p "$prompt" value
    [ -n "$value" ] || { echo "  Empty input, please try again." >&2; continue; }
    eval "$var=\"\$value\""
    return 0
  done
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

ln -sfv /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
hwclock --systohc

cat > /etc/locale.gen << "EOF"
en_US.UTF-8 UTF-8
zh_CN.UTF-8 UTF-8
EOF
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

echo "arch" > /etc/hostname
cat >> /etc/hosts << "EOF"
127.0.0.1    localhost
::1          localhost
EOF

echo "Setting root's password"
passwd root

if confirm "Would you like to create a normal user?"; then
  read_required "Enter the username: " USERNAME
  useradd -m -s /bin/bash -G wheel "$USERNAME"
  echo "Setting user $USERNAME's password"
  passwd "$USERNAME"
fi

sed -i "s?# %wheel ALL=(ALL:ALL) ALL?%wheel ALL=(ALL:ALL) ALL?" /etc/sudoers

if confirm "Would you like to generate the system boot?"; then
  echo "[1] GRUB2"
  echo "[2] rEFInd"
  read -e -p "Select a bootloader or boot manager: " BOOT_MANAGER
  case "$BOOT_MANAGER" in
    "1")
      pacman -Syyu --noconfirm efibootmgr grub
      grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=ARCH
      read -e -p "Enter the screen resolution (e.g. 1920x1080): " SCREEN_RESOLUTION
      sed -i "s?GRUB_GFXMODE=auto?GRUB_GFXMODE=\"$SCREEN_RESOLUTION\"?" /etc/default/grub
      sed -i "s?GRUB_CMDLINE_LINUX_DEFAULT=\"loglevel=3 quiet\"?GRUB_CMDLINE_LINUX_DEFAULT=\"loglevel=3\"?" /etc/default/grub
      if confirm "Enable os-prober to detect other os?"; then
        pacman -Syyu --noconfirm os-prober
        sed -i "s?#GRUB_DISABLE_OS_PROBER=false?GRUB_DISABLE_OS_PROBER=false?" /etc/default/grub
      fi
      grub-mkconfig -o /boot/grub/grub.cfg
      pacman -Scc
      ;;
    "2")
      pacman -Syyu --noconfirm refind
      refind-install
      lsblk
      read_partition "Enter the root partition (e.g. /dev/sda2): " ROOT_PARTITION
      read -e -p "Enter the screen resolution (e.g. 1920 1080): " SCREEN_RESOLUTION
      ROOT_PARTITION_LABEL="$(e2label "$ROOT_PARTITION")"
      ROOT_PARTITION_PARTUUID="$(blkid -s PARTUUID -o value "$ROOT_PARTITION")"
      cat >> /boot/efi/EFI/refind/refind.conf << EOF

# Override configuration
timeout 5

resolution $SCREEN_RESOLUTION

scan_all_linux_kernels false

menuentry "Arch Linux" {
  icon /EFI/refind/icons/os_arch.png
  volume "$ROOT_PARTITION_LABEL"
  loader /boot/vmlinuz-linux
  initrd /boot/initramfs-linux.img
  options "root=PARTUUID=$ROOT_PARTITION_PARTUUID rw loglevel=3"
}
EOF
      pacman -Scc
      ;;
    *)
      ;;
  esac
fi

confirm "Would you like to install preferred packages?" || exit 0
PKG_BASE=""
PKG_BASE+="bash-completion lsof ethtool inetutils net-tools p7zip rsync unrar unzip aria2 curl wget "
PKG_BASE+="htop iotop nethogs fastfetch numactl "
PKG_BASE+="iperf3 nmap openbsd-netcat networkmanager dhcpcd wpa_supplicant openssh "
PKG_BASE+="clang cmake gcc gdb git valgrind vim "
PKG_BASE+="dosfstools exfat-utils ntfs-3g "
PKG_BASE+="docker docker-compose "
PKG_BASE+="virtualbox virtualbox-guest-iso virtualbox-host-dkms "
PKG_BASE+="fcitx5-im fcitx5-pinyin-zhwiki fcitx5-chinese-addons fcitx5-lua "
PKG_BASE+="adobe-source-code-pro-fonts noto-fonts-emoji ttf-dejavu ttf-liberation wqy-zenhei "
PKG_BASE+="firefox firefox-i18n-zh-cn obs-studio vlc vlc-plugin-ffmpeg vlc-plugins-extra v2ray cups-pdf "
PKG_BASE+="xorg-server xorg-xrandr xorg-xwayland "
PKG_BASE+="libxml2-legacy "
PKG_DESKTOP=""
echo "[1] GNOME"
echo "[2] KDE Plasma"
echo "[3] BSPWM"
read -e -p "Select a desktop environment or window manager: " DESKTOP_ENVIRONMENT
case "$DESKTOP_ENVIRONMENT" in
  "1")
    PKG_DESKTOP+="gdm gnome-backgrounds gnome-control-center gnome-keyring gnome-session "
    PKG_DESKTOP+="gnome-settings-daemon gnome-shell gnome-shell-extensions gnome-browser-connector mutter "
    PKG_DESKTOP+="gnome-color-manager gnome-disk-utility gnome-video-effects gnome-remote-desktop "
    PKG_DESKTOP+="grilo-plugins gvfs-mtp gvfs-nfs gvfs-smb malcontent orca rygel "
    PKG_DESKTOP+="tracker3-miners xdg-user-dirs-gtk xdg-desktop-portal-gnome "
    PKG_DESKTOP+="baobab cheese eog evince file-roller gnome-calculator gnome-font-viewer "
    PKG_DESKTOP+="gnome-system-monitor nautilus simple-scan sushi system-config-printer totem "
    PKG_DESKTOP+="gedit gnome-terminal gnome-tweaks "
    PKG_DESKTOP+="gnome-shell-extension-appindicator gnome-shell-extension-dash-to-panel "
    pacman -Syyu --noconfirm $PKG_BASE $PKG_DESKTOP
    systemctl enable gdm
    ;;
  "2")
    PKG_DESKTOP+="plasma-desktop plasma-workspace plasma-workspace-wallpapers kwin sddm "
    PKG_DESKTOP+="kactivitymanagerd kdecoration kscreen kscreenlocker kwayland-integration "
    PKG_DESKTOP+="layer-shell-qt libkscreen libksysguard milou polkit-kde-agent powerdevil "
    PKG_DESKTOP+="bluedevil breeze breeze-gtk drkonqi kde-cli-tools kde-gtk-config "
    PKG_DESKTOP+="kdeplasma-addons kinfocenter kmenuedit kpipewire ksshaskpass ksystemstats "
    PKG_DESKTOP+="kwallet-pam kwrited plasma-browser-integration plasma-disks plasma-firewall "
    PKG_DESKTOP+="plasma-integration plasma-nm plasma-pa plasma-sdk plasma-systemmonitor "
    PKG_DESKTOP+="plasma-thunderbolt plasma-vault print-manager sddm-kcm systemsettings "
    PKG_DESKTOP+="xdg-desktop-portal-kde "
    PKG_DESKTOP+="ark dolphin flameshot gwenview kate konsole skanlite skanpage "
    pacman -Syyu --noconfirm $PKG_BASE $PKG_DESKTOP
    systemctl enable sddm
    ;;
  "3")
    PKG_DESKTOP+="bspwm sxhkd alacritty polybar rofi picom feh flameshot wmname "
    PKG_DESKTOP+="xorg-xinit xorg-xsetroot "
    PKG_DESKTOP+="alsa-utils blueman network-manager-applet pasystray pulseaudio udiskie "
    PKG_DESKTOP+="system-config-printer "
    pacman -Syyu --noconfirm $PKG_BASE $PKG_DESKTOP
    ;;
  *)
    exit 0
    ;;
esac

if [ -n "$USERNAME" ]; then
  usermod -a -G vboxusers "$USERNAME"
fi
systemctl enable cups docker bluetooth NetworkManager
pacman -Scc
