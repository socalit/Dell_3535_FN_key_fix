# Dell Inspiron 15 3535 — FN Key Fix for Linux Mint

![Dell Inspiron 15 3535](dell_3535.jpg)

[![Buy Me a Coffee](https://img.shields.io/badge/Buy%20Me%20a%20Coffee-support-%23FFDD00?logo=buymeacoffee&logoColor=black)](https://buymeacoffee.com/socal370xs)
[![Linux Mint](https://img.shields.io/badge/Linux-Mint%2021%2B-brightgreen?logo=linux-mint&logoColor=white)](https://linuxmint.com/)
[![Dell](https://img.shields.io/badge/Dell-Inspiron%2015%203535-blue?logo=dell&logoColor=white)](https://www.dell.com/)
[![Bash](https://img.shields.io/badge/Script-Bash-black?logo=gnu-bash&logoColor=white)](#)
[![ACPI](https://img.shields.io/badge/Kernel-ACPI%20%7C%20WMI%20Fix-orange?logo=linux&logoColor=white)](#)
[![Fingerprint](https://img.shields.io/badge/Fingerprint-fprintd%20Support-success?logo=pinboard&logoColor=white)](#)
[![License](https://img.shields.io/badge/license-MIT-purple)](/LICENSE)

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
git clone https://github.com/socalit/Dell_3535_FN_key_fix.git
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

## Recommended: Update Your BIOS First

Before running this script, make sure your BIOS is up to date. An outdated BIOS can cause FN key and ACPI issues that no Linux fix can fully work around.

| Field | Details |
|-------|---------|
| Model | Dell Inspiron 15 3535 / Vostro 3435/3535 |
| Version | **1.28.0** |
| Released | March 10, 2026 |
| Category | Critical — Security + ACPI fixes |
| File | `Inspiron_3535_1.28.0.exe` (52.18 MB) |
| Source | [Dell Support — Drivers & Downloads](https://www.dell.com/support/product-details/en-us/product/inspiron-15-3535-laptop/drivers) |

> **Note:** Once upgraded to 1.28.0 you cannot downgrade to 1.23.0 or earlier. This update includes new 2023 Secure Boot Certificates and Dell Security Advisory (DSA) patches.

The `.exe` is Windows-only and the Inspiron 15 3535 is not listed on [LVFS](https://fwupd.org/), so `fwupd` will not work. The only Linux path is extracting the BIOS payload and flashing it from the BIOS menu.

---

### How to Update the BIOS from Linux Mint

**Step 1 — Download the BIOS update**

Go to [Dell Support — Drivers & Downloads](https://www.dell.com/support/product-details/en-us/product/inspiron-15-3535-laptop/drivers), filter by **BIOS**, and download `Inspiron_3535_1.28.0.exe` to your `~/Downloads` folder.

**Step 2 — Extract the `.exe`**

```bash
# Install 7-Zip
sudo apt install p7zip-full

# Extract
cd ~/Downloads
7z x Inspiron_3535_1.28.0.exe -o./bios_extracted

# Confirm isflash.bin is present
ls ./bios_extracted/
```

You should see `isflash.bin` — that is the BIOS payload used for flashing.

**Step 3 — Copy to a FAT32 USB drive**

```bash
# Find your USB drive letter (e.g. /dev/sdb)
lsblk

# Format as FAT32 — replace sdX1 with your USB partition (NOT your system drive)
sudo mkfs.vfat -F 32 /dev/sdX1

# Mount, copy, unmount
sudo mkdir -p /mnt/usbdrive
sudo mount /dev/sdX1 /mnt/usbdrive
sudo cp ~/Downloads/bios_extracted/isflash.bin /mnt/usbdrive/
sudo umount /mnt/usbdrive
```

> **Warning:** Double-check `lsblk` before formatting. Picking the wrong drive will erase it.

**Step 4 — Flash from BIOS**

1. Plug the USB into the Dell Inspiron 15 3535
2. Plug in the charger — AC power is required
3. Reboot → press **F2** to enter BIOS setup
4. Go to **Maintenance → BIOS Flash Update**
5. Browse to `isflash.bin` on the USB
6. Confirm — the laptop will reboot and flash automatically

> **Do not power off, close the lid, or unplug the charger during flashing.**

**Step 5 — Verify**

```bash
sudo dmidecode -s bios-version
# Expected output: 1.28.0
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

---

## Author

**SoCal IT**
Ethical hacker & Wi-Fi tools developer
GitHub: [https://github.com/socalit](https://github.com/socalit)

---

## Support

### ⭐ Star the GitHub repo
### Share it with communities
### Open issues or request features

If this project saved you time or solved a problem, consider supporting development:

[![Buy Me a Coffee](https://img.buymeacoffee.com/button-api/?text=Buy%20me%20a%20coffee&slug=socal370xs&button_colour=FFDD00&font_colour=000000&font_family=Arial&outline_colour=000000&coffee_colour=ffffff)](https://buymeacoffee.com/socal370xs)
