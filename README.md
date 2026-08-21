### Pre-commit
```bash
pip install pre-commit
pre-commit install
pre-commit run --all-files # To scan through all existing files
```

### Restore Kubernetes etcd

#### 1. Stop K3s services
```bash
sudo systemctl stop k3s # on master nodes
sudo systemctl stop k3s-agent # on worker nodes
```

#### 2. Restore `encryption-config.json`
You must restore `encryption-config.json` for K3s to decrypt secrets from snapshot. `encryption-config.json` can be found on Bitwarden Vault.

```bash
# Only on first master node
sudo mkdir -p /var/lib/rancher/k3s/server/cred/
sudo vi /var/lib/rancher/k3s/server/cred/encryption-config.json
sudo chmod 600 /var/lib/rancher/k3s/server/cred/encryption-config.json
```

#### 3. Restore etcd

1. Download snapshot and unzip the content
2. Move raw snapshot file to `/var/lib/rancher/k3s/server/db/snapshots/`.
3. Run following command:
```bash
# Only on first master node
sudo k3s server \
  --cluster-reset \
  --etcd-s3=false \
  --cluster-reset-restore-path="/var/lib/rancher/k3s/server/db/snapshots/<snapshot_file_name>"
```

Or if you're feeling adventurous and want to restore from online S3 storage:
```bash
# etcd-s3 must be configured on master nodes'
# /etc/rancher/k3s/config.yaml beforehand
sudo k3s server \
  --cluster-reset \
  --cluster-reset-restore-path="<snapshot_file_name>"
```

#### 4. Clear etcd on other master nodes
```bash
# NOT ON first master node

sudo rm -rf /var/lib/rancher/k3s/server/db
```

#### 5. Start K3s services
```bash
sudo systemctl start k3s # first master, wait, then remaining masters
sudo systemctl start k3s-agent # on worker nodes
```

Wait for Flux CD to fully reconcile before bootstraping Flux CD. You may also skip the bootstrap.

---

### Bootstrap Flux CD

#### 1. Create SOPS secret
Import age key for SOPS decryption:

```bash
# Create namespace
kubectl create namespace flux-system --dry-run=client -o yaml |
kubectl apply -f -

# Import age key to Kubernetes
cat age.agekey |
kubectl create secret generic sops-age \
  --namespace=flux-system \
  --from-file=age.agekey=/dev/stdin
```

#### 2. Bootstrap Flux CD
```bash
export GITHUB_TOKEN=<gh-token> # Omit this if you prefer to enter PAT interactively for security

flux bootstrap github \
  --components-extra image-reflector-controller,image-automation-controller \
  --token-auth \
  --owner=kimiroo \
  --repository=darak-cd \
  --branch=master \
  --path=clusters/darak-cluster \
  --personal
```