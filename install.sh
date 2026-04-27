#!/bin/bash

ask_yes_no() {
    local prompt="$1"
    local varname="$2"
    while true; do
        read -p "$prompt [y/n] " answer
        case "$answer" in
            [yY]|[yY]es)
                eval "$varname=true"
                return 0
                ;;
            [nN]|[nN]o)
                eval "$varname=false"
                return 0
                ;;
            *)
                echo "Please answer with 'y' or 'n'."
                ;;
        esac
    done
}

# detecting the distro
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        case $ID in
            arch|manjaro)
                echo "arch"
                ;;
            ubuntu|debian)
                echo "ubuntu"
                ;;
            fedora)
                echo "fedora"
                ;;
            *)
                echo "unsupported"
                ;;
        esac
    else
        echo "unsupported"
    fi
}

# install packages on arch
install_arch() {
    echo "[*] Detected Arch Linux"

    if [ "$install_all_packages" = "true" ]; then
        # install yay programs
        yay -Syu --noconfirm && yay -S --noconfirm minecraft-launcher onlyoffice-bin
    fi

    # official repo
    sudo pacman -Sy --noconfirm jre-openjdk texlive-basic texlive-bibtexextra texlive-binextra texlive-context texlive-fontsextra texlive-fontsrecommended texlive-fontutils texlive-formatsextra texlive-humanities texlive-latex texlive-latexextra texlive-latexrecommended texlive-luatex texlive-mathscience texlive-pictures texlive-publishers texlive-xetex texstudio biber flatpak baobab gnome-disk-utility obs-studio steam strawberry signal-desktop discord clamav clamtk firejail usbguard pavucontrol audacity handbrake btop code nginx keepassxc plasma-vault gimp digikam qemu-full libvirt virt-manager dnsmasq ebtables edk2-ovmf bubblewrap nsjail rkhunter arpwatch veracrypt kleopatra nftables torbrowser-launcher apparmor proton-vpn-gtk-app inkscape wireshark-qt nmap bleachbit sbctl discover nextcloud-client spotify-launcher k3b picard htop iftop atop bettercap hashcat kdenlive thunderbird qbittorrent firetools kdiskmark aircrack-ng blender homebank rpm vlc mediathekview magic-wormhole aspell hunspell hunspell-en_gb hunspell-de hunspell-en_gb aspell-en aspell-de texlive-langgerman texlive-langeuropean texlive-langfrench texlive-langcyrillic qrca krfb cdrtools cdrdao dvd+rw-tools msmtp-mta cronie

    if [ "$intel" = "true" ]; then
	# install intel firmware
	sudo pacman -S --noconfirm intel-media-driver linux-firmware-intel intel-compute-runtime xf86-video-intel
    fi

    if [ "$amd" = "true" ]; then
	echo '[!] Sadly, AMD is not yet supported in this script, no further modifications are being made in this regard..'
    fi

    if [ "$nvidia" = "true" ]; then
	echo '[!] When using arch it is important to select the nvidia version when booting up the installer, minor modifications are now being made in this regard.'
	sudo pacman -Sy --noconfirm nvidia-utils cuda
    fi
}

# install packages on Ubuntu
install_ubuntu() {
    echo "[*] Detected Ubuntu. Using apt to install packages."
    sudo apt update && sudo apt upgrade -y
	clear
	echo '[!] Support will be added soon!'
}

# install packages on Fedora
install_fedora() {
    echo "[*] Detected Fedora. Using dnf to install packages."
	sudo dnf upgrade -y && sudo flatpak update -y
    sudo dnf install -y --skip-unavailable texlive texstudio biber flatpak baobab gnome-disk-utility obs-studio strawberry clamav clamtk firejail usbguard pavucontrol audacity btop nginx keepassxc plasma-vault gimp digikam qemu libvirt virt-manager dnsmasq ebtables edk2-ovmf bubblewrap rkhunter arpwatch kleopatra nftables torbrowser-launcher inkscape nmap bleachbit nextcloud-client k3b picard htop iftop atop hashcat kdenlive thunderbird qbittorrent kdiskmark aircrack-ng blender homebank rpm vlc aspell hunspell hunspell-de aspell-en aspell-de qrca krfb snap plasma-discover-snap wireshark
	sudo snap install spotify signal-desktop steam discord
	sudo flatpak install -y app/fr.handbrake.ghb/x86_64/stable app/com.protonvpn.www/x86_64/stable
	clear
    echo '[!] The following packages are not supported - manual intervention required: code veracrypt bettercap firetools intel-media-driver linux-firmware-intel xf86-video-intel mediathekview magic-wormhole hunspell-en_gb texlive-langgerman texlive-langeuropean texlive-langfrench texlive-langcyrillic'
	# echo '[!] Support will be added soon!'
}

# _________________________________________________________________________________

# Main script
# _________________________________________________________________________________

ask_yes_no "Do you want to install packages from non official repositories?" install_all_packages
ask_yes_no "Do you want to reboot the system once the setup is done?" automatic_reboot
ask_yes_no "Do you want to enable usbguard?" usbguard
ask_yes_no "Are you using an Intel CPU?" intel
ask_yes_no "Are you using an AMD CPU?" amd
ask_yes_no "Are you using an NVIDIA GPU?" nvidia
ask_yes_no "Do you plan on using Tailscale?" tailscale
ask_yes_no "Do you plan on using bluetooth on your device?" bluetooth

DISTRO=$(detect_distro)

if [ "$DISTRO" != "unsupported" ]; then
    case $DISTRO in
        arch)
            install_arch "$@"
            ;;
        ubuntu)
            install_ubuntu "$@"
            ;;
        fedora)
            install_fedora "$@"
            ;;
    esac

    # post install
    echo "[*] Running post-installation steps..."

    # add the sg module to the kernel autoload modules - otherwise a usb dvd drive will not be detected
    echo '[+] Adding the sg module to /etc/modules-load.d/sg.conf to enable usb-optical-drive support'
    sudo bash -c 'echo sg > /etc/modules-load.d/sg.conf'

    # enabling qemu virtualisation support and enabling the service as well as the anti-virus clamav
    sudo usermod -aG libvirt $(whoami) && sudo systemctl enable --now libvirtd clamav-daemon && sudo freshclam

	if [ "install_all_packages" = "true" ]
		sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
	fi

    # Enable usbguard if requested
    if [ "$usbguard" = "true" ]; then
        echo "[+] Enabling usbguard..."
        sudo systemctl enable --now usbguard
    fi

    # reboot if requested
    if [ "$automatic_reboot" = "true" ]; then
        echo "[+] Rebooting the system..."
        sudo reboot
    fi

    if [ "$tailscale" = "true" ]; then
	echo '[+] Installing tailscale'
	curl -fsSL https://tailscale.com/install.sh | sh
	sudo tailscale up
    fi

    if [ "$bluetooth" = "true" ]; then
	echo '[+] Enabling bluetooth...'
	sudo systemctl enable --now bluetooth
    fi 

else
    echo "Unsupported distribution: $DISTRO"
    exit 1
fi
