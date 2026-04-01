# Dell Inspiron 15 3535 — FN Key Fix for Linux Mint

A bash script that automatically fixes non-working FN keys on the **Dell Inspiron 15 3535** running **Linux Mint**. Also detects and sets up a fingerprint reader if one is present.

---

## The Problem

On Linux Mint, the Dell Inspiron 15 3535's FN keys (brightness, volume, mute, etc.) often stop working out of the box. This happens because:

- The BIOS ACPI firmware defaults to Windows behavior and routes FN key events through Windows-specific paths that Linux never receives
- The required Dell kernel modules are not loaded by default
- Some FN key scancodes are not mapped to Linux keycodes

---

## What the Script Does

| Step | Action |
|------|--------|
| 1 | Backs up `/etc/default/grub` before making any changes |
| 2 | Adds `acpi_osi=Linux`, `acpi_backlight=native`, and `pcie_aspm=off` as kernel boot parameters |
| 3 | Loads `dell-laptop`, `dell-wmi`, and `sparse-keymap` kernel modules and persists them across reboots |
| 4 | Ensures `acpi-support` is installed |
| 5 | Installs a `udev` hwdb rule to map FN key scancodes (mute, volume up/down) |
| 6 | Detects a fingerprint reader and sets it up if found (installs `fprintd`, configures PAM, optionally enrolls your finger) |
| 7 | Runs `update-grub` to apply boot parameter changes |

---

## Requirements

- Dell Inspiron 15 3535
- Linux Mint (Ubuntu/Debian-based)
- GRUB bootloader
- Internet connection (for package installs if needed)

---

## Usage

```bash
# Clone the repo
git clone https://github.com/YOUR_USERNAME/Dell_3535_FN_key_fix.git
cd Dell_3535_FN_key_fix

# Make the script executable
chmod +x dell-fn-fix.sh

# Run as root
sudo bash dell-fn-fix.sh
```

Reboot when prompted for all changes to take effect.

---

## Fingerprint Reader

The script automatically detects fingerprint readers from the following vendors:

| Vendor | Chip |
|--------|------|
| Goodix | `27c6` |
| Synaptics | `06cb` |
| AuthenTec | `08ff` |
| Validity Sensors | `138a` |
| ELAN | `04f3` |

If a reader is found, the script installs `fprintd` + `libpam-fprintd`, enables the service, configures PAM (login, sudo, lock screen), and optionally walks you through enrolling your fingerprint.

To manage fingerprints manually after setup:

```bash
fprintd-enroll                  # enroll a finger (defaults to right-index)
fprintd-enroll -f left-index    # enroll a specific finger
fprintd-list $USER              # list enrolled fingers
fprintd-delete $USER            # remove all enrolled fingers
```

---

## If FN Keys Still Don't Work After Reboot

**A) Check your BIOS setting (most reliable fix for multimedia keys)**
1. Reboot and press **F2** to enter BIOS
2. Go to **System Configuration > Function Key Behavior**
3. Set to **Function** (not Multimedia)
4. Alternatively, press **Fn + Esc** at the login screen to toggle FN Lock

**B) Diagnose which scancodes your keyboard emits**
```bash
sudo evtest
# Select your keyboard, then press FN+F1, FN+F2, etc. and note the scancodes
```

**C) If brightness keys (FN+F11 / FN+F12) specifically don't work**

Edit `/etc/default/grub` and replace `acpi_backlight=native` with `acpi_backlight=video`, then:
```bash
sudo update-grub && sudo reboot
```

---

## Reverting Changes

The script backs up your GRUB config automatically:

```bash
# Find your backup
ls /etc/default/grub.bak.*

# Restore it
sudo cp /etc/default/grub.bak.YYYYMMDD_HHMMSS /etc/default/grub
sudo update-grub
```

To remove the module and udev configs:
```bash
sudo rm /etc/modules-load.d/dell-fn.conf
sudo rm /etc/udev/hwdb.d/61-dell-fn-keys.hwdb
sudo systemd-hwdb update
```

---

## Tested On

| Laptop | OS | Status |
|--------|----|--------|
| Dell Inspiron 15 3535 (AMD Ryzen) | Linux Mint 21.x | Working |

---

## Contributing

If this worked (or didn't) on your setup, feel free to open an issue with your kernel version and `lsusb` output. PRs welcome for other Dell Inspiron models.

---

## License

MIT
