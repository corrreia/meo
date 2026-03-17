#!/bin/bash
set -e

username="${LINUX_USER:-${USERNAME:-work}}"
password="${LINUX_PASSWORD:-${PASSWORD:-work}}"
home_dir="/home/${username}"

if ! id -u "$username" >/dev/null 2>&1; then
  useradd -m -d "$home_dir" -s /bin/bash "$username"
fi

install -d -m 0755 -o "$username" -g "$username" "$home_dir"
echo "$username:$password" | chpasswd

ln -sfn /shared "$home_dir/Shared"
chown -h "$username:$username" "$home_dir/Shared"

printf '%s ALL=(ALL) NOPASSWD: ALL\n' "$username" > "/etc/sudoers.d/${username}"
chmod 0440 "/etc/sudoers.d/${username}"

mkdir -p /run/sshd

if [ -d /usr/local/share/ca-certificates/internal ]; then
  find /usr/local/share/ca-certificates/internal -type f \( -name '*.crt' -o -name '*.cer' -o -name '*.pem' \) | grep -q . && update_certs=1 || update_certs=0
  if [ "$update_certs" = "1" ]; then
    trust extract-compat
  fi
fi

cat > /etc/ssh/sshd_config.d/work.conf <<EOF
PasswordAuthentication yes
PermitRootLogin no
UsePAM yes
X11Forwarding no
PrintMotd no
EOF

exec /usr/bin/sshd -D -e
