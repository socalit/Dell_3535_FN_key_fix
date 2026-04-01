#!/bin/bash
# Dell Inspiron 15 3535 - FN Key Fix for Linux Mint OS
# Fixes: ACPI kernel params, Dell modules, key mappings

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log()  { echo -e "${GREEN}[+]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
err()  { echo -e "${RED}[x]${NC} $1"; }
info() { echo -e "${BLUE}[i]${NC} $1"; }

if [[ $EUID -ne 0 ]]; then
    err "This script must be run as root."
    echo "    Re-run with: sudo bash $0"
    exit 1
fi

echo ""
echo "======================================================="
echo "   Dell Inspiron 15 3535 - FN Key Fix (Linux Mint)"
echo "======================================================="
echo ""

GRUB_FILE="/etc/default/grub"
BACKUP="${GRUB_FILE}.bak.$(date +%Y%m%d_%H%M%S)"

if [[ ! -f "$GRUB_FILE" ]]; then
    err "/etc/default/grub not found. Is GRUB installed?"
    exit 1
fi

cp "$GRUB_FILE" "$BACKUP"
log "GRUB config backed up → $BACKUP"

add_grub_param() {
    local param="$1"
    if grep -qE "(^|\s)${param}(\s|\")" "$GRUB_FILE"; then
        warn "Kernel param '${param}' already present — skipping."
    else
        sed -i "s/\(GRUB_CMDLINE_LINUX_DEFAULT=\"\)/\1${param} /" "$GRUB_FILE"
        log "Added kernel param: ${param}"
    fi
}

info "Patching GRUB kernel parameters..."


add_grub_param "acpi_osi=Linux"


add_grub_param "acpi_backlight=native"


add_grub_param "pcie_aspm=off"

echo ""
info "Current GRUB_CMDLINE_LINUX_DEFAULT after patching:"
grep "^GRUB_CMDLINE_LINUX_DEFAULT" "$GRUB_FILE"
echo ""

MODULES_CONF="/etc/modules-load.d/dell-fn.conf"

load_module() {
    local mod="$1"
    if modprobe "$mod" 2>/dev/null; then
        log "Loaded module: ${mod}"
    else
        warn "Module '${mod}' not available on this kernel — skipping."
    fi
}

info "Loading Dell kernel modules..."
load_module dell-laptop
load_module dell-wmi
load_module dell-wmi-aio
load_module sparse-keymap

cat > "$MODULES_CONF" <<'EOF'
# Dell Inspiron FN key support — loaded at boot
dell-laptop
dell-wmi
sparse-keymap
EOF
log "Persisted modules → $MODULES_CONF"

info "Checking acpi-support package..."
if dpkg -s acpi-support &>/dev/null 2>&1; then
    log "acpi-support already installed."
else
    warn "acpi-support not found — installing..."
    apt-get install -y acpi-support
    log "acpi-support installed."
fi

HWDB_FILE="/etc/udev/hwdb.d/61-dell-fn-keys.hwdb"

info "Installing udev hwdb mapping for Dell keyboard..."
cat > "$HWDB_FILE" <<'EOF'
# Dell Inspiron keyboard — ensure FN-layer scancodes are mapped
# Matches any AT keyboard on a Dell system (works for built-in keyboards).
evdev:atkbd:dmi:bvn*:bvr*:bd*:svnDell*:pn*Inspiron*:*
 KEYBOARD_KEY_a0=mute
 KEYBOARD_KEY_ae=volumedown
 KEYBOARD_KEY_b0=volumeup
EOF


systemd-hwdb update
udevadm trigger --subsystem-match=input --action=change
log "udev hwdb updated and triggered."

info "Checking for fingerprint reader..."

FP_VENDORS="27c6\|06cb\|08ff\|138a\|04f3"
FP_DEVICE=$(lsusb 2>/dev/null | grep -i "$FP_VENDORS" | head -1 || true)

if [[ -n "$FP_DEVICE" ]]; then
    log "Fingerprint reader detected: $FP_DEVICE"

    
    info "Installing fingerprint packages..."
    apt-get install -y fprintd libpam-fprintd

   
    systemctl enable fprintd
    systemctl start fprintd
    log "fprintd service enabled and started."

    info "Configuring PAM for fingerprint authentication..."
    DEBIAN_FRONTEND=noninteractive pam-auth-update --enable fprintd
    log "PAM updated — fingerprint auth enabled for login, sudo, and lock screen."


    REAL_USER="${SUDO_USER:-}"
    if [[ -n "$REAL_USER" ]]; then
        echo ""
        warn "Enroll fingerprint for user '${REAL_USER}' now? (y/N)"
        read -r enroll_answer
        if [[ "${enroll_answer,,}" == "y" ]]; then
            info "Follow the prompts — swipe your finger 3 times."

            sudo -u "$REAL_USER" fprintd-enroll "$REAL_USER"
            log "Fingerprint enrolled for ${REAL_USER}."
            info "To enroll more fingers later:  fprintd-enroll -f <finger>"
            info "To list enrolled fingers:      fprintd-list ${REAL_USER}"
            info "To delete enrolled fingers:    fprintd-delete ${REAL_USER}"
        else
            warn "Skipped enrollment. Run 'fprintd-enroll' later to register your finger."
        fi
    else
        warn "Could not detect the original user. Run 'fprintd-enroll' manually after reboot."
    fi
else
    info "No fingerprint reader detected — skipping fingerprint setup."
    info "To check manually after reboot:  lsusb | grep -iE 'finger|validity|synaptics|goodix'"
fi


info "Updating GRUB bootloader..."
update-grub
log "GRUB updated."

echo ""
echo "======================================================="
log "All fixes applied. A reboot is required."
echo "======================================================="
echo ""
echo "  Changes made:"
echo "    [1] Kernel params added to GRUB:"
echo "        acpi_osi=Linux, acpi_backlight=native, pcie_aspm=off"
echo "    [2] Dell modules loaded now and set to load on boot:"
echo "        dell-laptop, dell-wmi, sparse-keymap"
echo "    [3] acpi-support package ensured"
echo "    [4] udev hwdb scancode mappings installed"
echo "    [5] Fingerprint reader: detected and configured (or skipped if not present)"
echo ""
echo "  If FN keys still don't work after reboot, also try:"
echo ""
echo "    A) BIOS fix (most reliable for multimedia FN keys):"
echo "       → Reboot → press F2 to enter BIOS"
echo "       → System Configuration > Function Key Behavior"
echo "       → Set to 'Function' (not 'Multimedia')"
echo "       → Or toggle with Fn + Esc at login screen"
echo ""
echo "    B) Test which FN scancodes your keyboard actually emits:"
echo "       → Run:  sudo evtest"
echo "       → Select your keyboard, then press FN+F1, FN+F2, etc."
echo "       → Share the output if you need custom keycode mappings"
echo ""
echo "    C) If brightness keys (FN+F11/F12) still don't work:"
echo "       → Try replacing 'acpi_backlight=native' with"
echo "         'acpi_backlight=video' in /etc/default/grub"
echo "         then run: sudo update-grub && reboot"
echo ""
warn "Reboot now?  (y/N)"
read -r answer
if [[ "${answer,,}" == "y" ]]; then
    log "Rebooting..."
    reboot
else
    warn "Remember to reboot before testing."
fi
