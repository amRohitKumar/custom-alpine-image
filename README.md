# 🚀 Custom Alpine VM Image with Docker, Node.js, Prometheus, and Grafana

This guide walks through the process of creating a custom Alpine Linux VM image for `x86_64` architecture, preconfigured with:

- Docker
- Node.js + NPM
- Prometheus
- Grafana
- Additional CLI tools (`curl`, `wget`, `git`, etc.)

## 🧰 Prerequisites

Ensure the following are installed **in WSL or your Linux environment**:

```bash
sudo apk add qemu-img qemu-nbd rsync sfdisk dosfstools curl wget git
```

Clone the alpine-make-vm-image tool:

```bash
curl -O https://raw.githubusercontent.com/alpinelinux/alpine-make-vm-image/master/alpine-make-vm-image
```

Now you should have a script named `alpine-make-vm-image` in your current directory. Make it executable:

```bash
chmod +x alpine-make-vm-image
```

## 🛠️ Create the VM Image

### 1. Create a Configuration Script

Create a file named `configure.sh` in the same directory as `alpine-make-vm-image` with the following content:

```bash
#!/bin/sh
set -ex

# Enable community repository
echo "https://dl-cdn.alpinelinux.org/alpine/latest-stable/community" >> /etc/apk/repositories
echo "https://dl-cdn.alpinelinux.org/alpine/edge/community" >> /etc/apk/repositories
echo "https://dl-cdn.alpinelinux.org/alpine/edge/testing" >> /etc/apk/repositories

# Update and install Docker
apk update

apk add docker grafana prometheus curl wget git vim bash openrc libc6-compat nodejs npm

# Create docker group if it doesn't exist
if ! getent group docker > /dev/null; then
    addgroup -S docker
fi

# Add root to docker group (if not already)
addgroup root docker || true

# Enable Docker service
rc-update add docker
rc-update add prometheus
rc-update add grafana

# -- Install Terraform manually --
TF_VERSION="1.6.6"
wget https://releases.hashicorp.com/terraform/${TF_VERSION}/terraform_${TF_VERSION}_linux_amd64.zip
unzip terraform_${TF_VERSION}_linux_amd64.zip -d /usr/local/bin/
rm terraform_${TF_VERSION}_linux_amd64.zip

# -- Install Node Exporter manually --
NODE_EXPORTER_VERSION="1.7.0"
wget https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz
tar -xzf node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz
cp node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64/node_exporter /usr/local/bin/
rm -rf node_exporter-${NODE_EXPORTER_VERSION}*

rc-update add loki || true
# Create scripts to add grafana and prometheus scripts

cat <<'EOF' > /root/start_prometheus
#!/bin/sh
prometheus --config.file=/etc/prometheus/prometheus.yml
EOF

chmod +x /root/start_prometheus

cat <<'EOF' > /root/start_grafana
#!/bin/sh
mkdir -p /usr/share/grafana/data/log
grafana-server --config=/usr/share/grafana/conf/defaults.ini --homepath=/usr/share/grafana > /usr/share/grafana/data/log/runtime.log
EOF
chmod +x /root/start_grafana

cat <<'EOF' > /root/start_all
#!/bin/sh
/root/start_prometheus.sh &
/root/start_grafana.sh &
EOF
chmod +x /root/start_all

rm -rf /var/cache/apk/*

# Pull github repository and run it
# Define your repo URL
REPO_URL="https://github.com/amRohitKumar/grafana-express-server"
CLONE_DIR="/root/grafana-express-server"

# Clone the repo
if [ ! -d "$CLONE_DIR" ]; then
  echo "Cloning repository..."
  git clone "$REPO_URL" "$CLONE_DIR"
else
  echo "Repository already cloned."
fi

# Go into the repo
cd "$CLONE_DIR"

# Install packages
echo "Installing npm packages..."
npm install

```

### 2. Create the VM Image

Run the following command to create the VM image with the specified packages and configuration script:

```bash
sudo ./alpine-make-vm-image \
        --image-format qcow2 \
        --image-size 5G \
        --packages "curl wget git vim docker kubectl ansible prometheus grafana loki nodejs npm" \
        --script-chroot \
        custom-alpine.qcow2 \
        ./configure.sh
```

This command creates a VM image named `custom-alpine.qcow2` with a size of 5GB, including the specified packages.

### 3. Run the VM Image

To run the VM image, you can use QEMU. Here’s an example command:

```bash
qemu-system-x86_64 \
  -m 2048 \
  -smp 4 \
  -enable-kvm \
  -cpu host \
  -net nic -net user,hostfwd=tcp::3000-:3000,hostfwd=tcp::9090-:9090\
  custom-alpine.qcow2
```

This command allocates 2GB of RAM and 4 CPU cores to the VM. It also forwards ports 3000 (for prometheus) and 9090 (for grafana) from the host to the VM, allowing access to Grafana and Prometheus.

## 4. Start Services
After the VM is running, you can start the services by executing the following commands inside the VM:

```bash
./ start_grafana 
cd /root/grafana-express-server && npm run start
```

## 5. Accessing the Services

- **Grafana**: Open your browser and go to `http://localhost:3000`. The default username and password are both `admin`. Use dashboard ID `11159` to create node dashboard.
- **Prometheus**: Open your browser and go to `http://localhost:9090`.
- **Node Exporter**: Open your browser and go to `http://localhost:9100/metrics`.
- **Loki**: Open your browser and go to `http://localhost:3100/metrics`.
