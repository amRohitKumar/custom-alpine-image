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
# Stop grafan-server if it is running
rc-service grafana stop

# Start grafana-server with custom config
grafana-server --config=/usr/share/grafana/conf/defaults.ini --homepath=/usr/share/grafana > /usr/share/grafana/data/grafana.log 2>&1 &

# Check if grafana-server is running
jobs -l

# Start express server
cd /root/grafana-express-server && npm run start

# Check if express server is running
curl http://localhost:8080

# Configure prometheus to use our express server as a target
vim /etc/prometheus/prometheus.yml

# Update the target inside static_configs, finally it should look like this:
# static_configs:
#    - targets: ['localhost:8080']
```

## 5. Accessing the Services

- **Grafana**: Open your browser and go to `http://localhost:3000`. The default username and password are both `admin`. Use dashboard ID `11159` to create node dashboard.
- **Prometheus**: Open your browser and go to `http://localhost:9090`.
- **Express Server**: Open your browser and go to `http://localhost:8080` (on virtual machine).

## 6. Prometheus Visualization

- To visualize the metrics, you can go to `http://localhost:9090/targets` and check if the target is up.

## 7. Grafana Visualization

- To visualize the metrics in Grafana, start with adding a new data source. Choose Prometheus as the data source type and set the URL to `http://localhost:9090`.
- After adding the data source, you can create a new dashboard and add panels to visualize the metrics collected by Prometheus. Select import from the dashboard ID `11159` to create a node dashboard.
- You can also create custom queries to visualize specific metrics. For example, to visualize CPU usage, you can use the following query:

## 8. Stopping the VM

To stop the VM, you can use the following command:

```bash
# run this command inside the VM
poweroff
```
