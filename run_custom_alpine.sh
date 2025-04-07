qemu-system-x86_64 \
  -m 2048 \
  -smp 4 \
  -enable-kvm \
  -cpu host \
  -net nic -net user,hostfwd=tcp::3000-:3000,hostfwd=tcp::9090-:9090\
  custom-alpine.qcow2
