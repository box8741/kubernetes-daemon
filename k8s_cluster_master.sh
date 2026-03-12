#!/bin/bash

set -e

# 기존 클러스터 초기화
kubeadm reset -f
rm -rf /etc/cni/net.d
rm -rf /var/lib/etcd
rm -rf $HOME/.kube

systemctl restart containerd

# CNI(Calico)를 위한 CIDR 설정 포함
kubeadm init --pod-network-cidr 192.168.0.0/16 --service-cidr=172.30.0.0/12

# 환경 변수 설정 (현재 세션 및 영구 적용)
mkdir -p $HOME/.kube
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config

# Calico 설치
wget -O tigera-operator.yaml https://raw.githubusercontent.com/projectcalico/calico/v3.27.3/manifests/tigera-operator.yaml
wget -O custom-resources.yaml https://raw.githubusercontent.com/projectcalico/calico/v3.27.3/manifests/custom-resources.yaml

kubectl create -f tigera-operator.yaml
sleep 5
kubectl create -f custom-resources.yaml

# Docker Login 기반 Secret 생성 (Harbor 접근용)
# 이 시점에 이미 docker login이 되어 있어야 /root/.docker/config.json이 존재
if [ -f /root/.docker/config.json ]; then
    kubectl create secret generic harbor-secret \
      --from-file=.dockerconfigjson=/root/.docker/config.json \
      --type=kubernetes.io/dockerconfigjson
fi

clear

echo "============================================================"
echo "      Kubernetes Master 노드 설정이 완료되었습니다!           "
echo "============================================================"
echo ""
echo "    아래의 Join 명령어를 복사하여 워커 노드에서 실행하세요      "
echo "------------------------------------------------------------"
echo ""
kubeadm token create --print-join-command
echo ""
echo "------------------------------------------------------------"
