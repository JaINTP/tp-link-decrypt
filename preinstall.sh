#!/bin/bash

RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
RESET="\e[0m"

# Function for logging messages
log_message() {
  echo -e "${GREEN}[INFO]${RESET} $1"
}

log_warning() {
  echo -e "${YELLOW}[WARNING]${RESET} $1"
}

log_error() {
  echo -e "${RED}[ERROR]${RESET} $1"
  exit 1
}

# Ensure script has access to sudo if installing packages
if [ "$EUID" -ne 0 ] && ! sudo -v > /dev/null 2>&1; then
  log_warning "You might need to enter your sudo password to install system packages."
fi

install_packages_apt() {
  log_message "Updating apt package list..."
  sudo apt-get update || log_warning "Failed to update apt package list."
  local packages=(wget build-essential python3 python3-pip python3-setuptools git gcc make cmake g++ xxd binwalk binutils-mips-linux-gnu)
  for pkg in "${packages[@]}"; do
    log_message "Installing $pkg..."
    sudo apt-get install -y "$pkg" || log_warning "Failed to install $pkg"
  done
}

install_packages_pacman() {
  log_message "Updating pacman package list..."
  sudo pacman -Sy || log_warning "Failed to update pacman package list."
  local packages=(wget base-devel python python-pip python-setuptools git gcc make cmake xxd binwalk)
  for pkg in "${packages[@]}"; do
    log_message "Installing $pkg..."
    sudo pacman -S --noconfirm "$pkg" || log_warning "Failed to install $pkg"
  done
  
  if ! command -v mips-linux-gnu-nm > /dev/null 2>&1; then
    log_warning "mips-linux-gnu-binutils not found. Attempting to install via AUR..."
    if command -v yay > /dev/null 2>&1; then
      yay -S --noconfirm mips-linux-gnu-binutils || log_warning "Failed to install mips-linux-gnu-binutils via yay"
    elif command -v paru > /dev/null 2>&1; then
      paru -S --noconfirm mips-linux-gnu-binutils || log_warning "Failed to install mips-linux-gnu-binutils via paru"
    else
      log_warning "No AUR helper (yay/paru) found. Please manually install 'mips-linux-gnu-binutils' from the AUR."
    fi
  fi
}

install_packages_dnf() {
  local packages=(wget make automake gcc gcc-c++ kernel-devel python3 python3-pip python3-setuptools git cmake vim-common binwalk)
  for pkg in "${packages[@]}"; do
    log_message "Installing $pkg..."
    sudo dnf install -y "$pkg" || log_warning "Failed to install $pkg"
  done
}

install_packages_zypper() {
  local packages=(wget make automake gcc gcc-c++ python3 python3-pip python3-setuptools git cmake vim binwalk)
  for pkg in "${packages[@]}"; do
    log_message "Installing $pkg..."
    sudo zypper install -y "$pkg" || log_warning "Failed to install $pkg"
  done
}

log_message "Detecting Linux distribution package manager..."

if command -v apt-get > /dev/null 2>&1; then
  log_message "Detected apt-based distribution."
  install_packages_apt
elif command -v pacman > /dev/null 2>&1; then
  log_message "Detected pacman-based distribution."
  install_packages_pacman
elif command -v dnf > /dev/null 2>&1; then
  log_message "Detected dnf-based distribution."
  install_packages_dnf
elif command -v zypper > /dev/null 2>&1; then
  log_message "Detected zypper-based distribution."
  install_packages_zypper
else
  log_error "Unsupported Linux distribution. Could not find apt, pacman, dnf, or zypper."
fi

log_message "Checking for 'uv' Python package manager..."
if ! command -v uv > /dev/null 2>&1; then
  log_message "Installing 'uv'..."
  curl -LsSf https://astral.sh/uv/install.sh | sh
  export PATH="$HOME/.cargo/bin:$HOME/.local/bin:$PATH"
fi

if command -v uv > /dev/null 2>&1; then
  log_message "Installing Python libraries ubi_reader and unblob using uv..."
  if [ "$EUID" -eq 0 ]; then
    log_warning "Running as root. uv tool install should be run as a normal user. Falling back to sudo -u \$SUDO_USER..."
    if [ -n "$SUDO_USER" ]; then
      sudo -u "$SUDO_USER" uv tool install ubi-reader || log_warning "Failed to install ubi-reader via uv tool"
      sudo -u "$SUDO_USER" uv tool install unblob || log_warning "Failed to install unblob via uv tool"
    else
      uv tool install ubi-reader || log_warning "Failed to install ubi-reader via uv tool"
      uv tool install unblob || log_warning "Failed to install unblob via uv tool"
    fi
  else
    uv tool install ubi-reader || log_warning "Failed to install ubi-reader via uv tool"
    uv tool install unblob || log_warning "Failed to install unblob via uv tool"
  fi
else
  log_error "Failed to install 'uv'. Cannot install ubi_reader and unblob securely."
fi

# Function to verify installed components
verify_component() {
  local component=$1
  echo -n "$component: "
  if command -v "$component" > /dev/null 2>&1; then
    log_message "$component installed."
  else
    log_warning "$component not found."
  fi
}

log_message "Verifying installed components..."
verify_component xxd
verify_component binwalk
verify_component git
verify_component gcc
verify_component make
verify_component cmake
verify_component g++

if command -v mips-linux-gnu-nm > /dev/null 2>&1; then
  verify_component mips-linux-gnu-nm
else
  verify_component nm
fi

echo -n "ubi_reader: "
if command -v ubireader_extract_files > /dev/null 2>&1 || ( [ -n "$SUDO_USER" ] && sudo -u "$SUDO_USER" command -v ubireader_extract_files > /dev/null 2>&1 ); then
  log_message "ubi_reader binary found."
elif [ -f "$HOME/.local/bin/ubireader_extract_files" ]; then
  log_message "ubi_reader binary found in $HOME/.local/bin."
else
  log_warning "ubi_reader binary not found in standard PATH. Please make sure ~/.local/bin is in your PATH."
fi

echo -n "unblob: "
if command -v unblob > /dev/null 2>&1 || ( [ -n "$SUDO_USER" ] && sudo -u "$SUDO_USER" command -v unblob > /dev/null 2>&1 ); then
  log_message "unblob binary found."
elif [ -f "$HOME/.local/bin/unblob" ]; then
  log_message "unblob binary found in $HOME/.local/bin."
else
  log_warning "unblob binary not found in standard PATH. Please make sure ~/.local/bin is in your PATH."
fi

log_message "Installation completed!"
