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


