#!/bin/bash

set -e

SWAPFILE="/swapfile"
DEFAULT_SWAPSIZE_MB=2048

# Header
echo -e "\n\033[1;35m✨ Starting Swapfile wizard...\033[0m\n"

function print_menu() {
    echo "Choose an option:"
    echo "  [1] Enable swap (default: ${DEFAULT_SWAPSIZE_MB} MB)"
    echo "  [2] Disable swap"
    echo "  [0] Exit"
}

function enable_swap() {
    local size="$1"

    if [ -z "$size" ]; then
        read -rp "Enter swap size in MB [${DEFAULT_SWAPSIZE_MB}]: " input_size
        size="${input_size:-$DEFAULT_SWAPSIZE_MB}"
    fi

    if [ -f "$SWAPFILE" ]; then
        echo "Swap file already exists. Disabling and removing it..."
        disable_swap
    fi

    echo "Creating swap file with ${size} MB..."
    fallocate -l "${size}M" "$SWAPFILE" || dd if=/dev/zero of="$SWAPFILE" bs=1M count="$size"
    chmod 600 "$SWAPFILE"
    mkswap "$SWAPFILE"
    swapon "$SWAPFILE"

    if ! grep -q "$SWAPFILE" /etc/fstab; then
        echo "$SWAPFILE none swap sw 0 0" >> /etc/fstab
    fi

    echo "Swap enabled with ${size} MB"
    echo -e "\nCurrent swap status:"
    swapon --show
}

function disable_swap() {
    if swapon --show | grep -q "$SWAPFILE"; then
        echo "Disabling swap..."
        swapoff "$SWAPFILE"
    fi

    if grep -q "$SWAPFILE" /etc/fstab; then
        echo "Removing $SWAPFILE from /etc/fstab..."
        sed -i "\|$SWAPFILE|d" /etc/fstab
    fi

    if [ -f "$SWAPFILE" ]; then
        echo "Deleting swap file..."
        rm -f "$SWAPFILE"
    fi

    echo "Swap disabled and removed"
    echo -e "\nCurrent swap status:"
    swapon --show
}

# Parse CLI options
if [[ "$1" == "--enable" ]]; then
    shift
    if [[ "$1" == "--size" && -n "$2" ]]; then
        enable_swap "$2"
    else
        enable_swap
    fi
    exit 0
elif [[ "$1" == "--disable" ]]; then
    disable_swap
    exit 0
fi

# Interactive menu if no args
print_menu
read -rp "Your choice: " choice

case "$choice" in
    1)
        enable_swap
        ;;
    2)
        disable_swap
        ;;
    0)
        echo "Exiting..."
        exit 0
        ;;
    *)
        echo "Invalid option"
        exit 1
        ;;
esac
