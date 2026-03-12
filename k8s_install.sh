#!/bin/bash

set -e

# Swap 비활성화 및 설정
swapoff -a
sed -i '/swap/s/^/#/' /etc/fstab

# 커널 모듈 로드 및 네트워크 파라미터 설정
cat <<EOF | tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter

cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.ipv4.ip_forward=1
net.bridge.bridge-nf-call-iptables=1
net.bridge.bridge-nf-call-ip6tables=1
EOF
sysctl --system

# Docker & Containerd 설치
set -euf -o pipefail
PS4='>>> '
set -x

# Install dependencies
sudo apt update && sudo apt install -y ca-certificates curl gnupg lsb-release

# Add Docker’s official GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --yes --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Set up the stable repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker CE
sudo apt update && sudo apt install -y docker-ce docker-ce-cli containerd.io

# Containerd 상세 설정 (Cgroup 및 Insecure Registry)
mkdir -p /etc/containerd
containerd config default > /etc/containerd/config.toml

sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml

systemctl restart containerd

# Kubernetes 패키지 설치 (v1.29 ??)
sudo apt update && sudo apt install -y apt-transport-https ca-certificates curl gpg
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /' | tee /etc/apt/sources.list.d/kubernetes.list

sudo apt update && sudo apt install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl

# 서비스 시작 및 상태 확인
systemctl daemon-reload
systemctl enable --now kubelet
systemctl restart containerd

clear

# docker 로그인
docker login
