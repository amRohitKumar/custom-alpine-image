sudo ./alpine-make-vm-image \
	--image-format qcow2 \
	--image-size 5G \
	--packages "curl wget git vim docker kubectl ansible prometheus grafana loki nodejs npm" \
	--script-chroot \
	custom-alpine.qcow2 \
	./configure.sh
