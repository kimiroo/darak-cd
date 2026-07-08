### Bootstrap Flux CD
```bash
flux bootstrap github \
  --components-extra image-reflector-controller,image-automation-controller \
  --token-auth \
  --owner=kimiroo \
  --repository=ichika-cd \
  --branch=master \
  --path=clusters/ichika-cluster \
  --personal
```