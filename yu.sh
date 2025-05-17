#!/bin/bash
set -e

# Pastikan dijalankan sebagai root
if [ "$(id -u)" -ne 0 ]; then
  echo "⚠️  Script ini harus dijalankan sebagai root!"
  exit 1
fi

echo "🔁 Memulai reset sistem Manjaro..."

# 1. Reset machine-id
echo "🧩 Reset machine-id..."
rm -f /etc/machine-id
systemd-machine-id-setup

# 2. Ganti hostname acak
NEW_HOST="manjaro-$(openssl rand -hex 3)"
hostnamectl set-hostname "$NEW_HOST"
echo "🖥️ Hostname diubah ke: $NEW_HOST"

# 3. Ganti MAC address (sementara)
echo "🌐 Mengganti MAC address sementara..."
IFACE=$(ip -o link show | awk -F': ' '{print $2}' | grep -E '^enp|^eth' | head -n1)
if [ -n "$IFACE" ]; then
  mac=$(printf '02:%02x:%02x:%02x:%02x:%02x\n' $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)))
  ip link set "$IFACE" down
  ip link set "$IFACE" address "$mac"
  ip link set "$IFACE" up
  echo "✅ MAC address baru untuk $IFACE: $mac"
else
  echo "⚠️  Tidak ditemukan interface ethernet yang cocok."
fi

# 4. Hapus semua user selain root
echo "🧹 Menghapus semua user selain root..."
for u in $(awk -F: '$3 >= 1000 {print $1}' /etc/passwd); do
  echo "🗑️  Menghapus user: $u"
  userdel -r "$u" || true
done

# 5. Hapus aplikasi-aplikasi non-default (XFCE dibiarkan)
echo "🧼 Menghapus aplikasi tambahan..."
APPS=(firefox chromium libreoffice gimp vlc hexchat thunderbird)
for app in "${APPS[@]}"; do
  if pacman -Q $app &> /dev/null; then
    echo "🗑️  Uninstall: $app"
    pacman -Rns --noconfirm $app
  fi
done

# 6. Bersihkan konfigurasi user lama
echo "🧹 Membersihkan konfigurasi pengguna lama..."
rm -rf /home/*/.cache /home/*/.config /home/*/.local /home/*/.mozilla /home/*/Downloads/*

# 7. Buat user baru default
echo "👤 Membuat user baru: user"
useradd -m -G wheel -s /bin/bash user
echo "user:yes12345" | chpasswd

# 8. Reset password root
echo "🔐 Set password root ke default"
echo "root:yes12345" | chpasswd

# 9. Kosongkan log dan riwayat
echo "🧽 Membersihkan log dan history..."
journalctl --rotate
journalctl --vacuum-time=1s
> /root/.bash_history
> /home/user/.bash_history 2>/dev/null || true

# 10. Selesai dan reboot
echo "✅ Reset selesai. Sistem akan reboot dalam 10 detik..."
sleep 10
reboot
