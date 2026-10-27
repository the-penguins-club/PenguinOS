# PenguinOS Justfile

HF_BUCKET := "linuxhasan/penguinos"
ISO_NAME := "PenguinOS-1.0-alpha.iso"
SHA_NAME := "PenguinOS-1.0-alpha.iso.sha256"
DISK_NAME := "penguinos-test-disk.qcow2"
DISK_SIZE := "40G"
OUTPUT_DIR := "."
SEED_ISO := OUTPUT_DIR + "/seed.iso"
CLOUD_INIT_SRC := OUTPUT_DIR + "/cloud-init"

# Default action
default:
	@just --list

# 1. Check remote checksum and verify if local ISO is up-to-date
# ⚠️ not tested yet..
check:
	#!/usr/bin/env bash
	set -e
	echo "==> Fetching remote checksum..."
	curl -L -s -o "{{SHA_NAME}}.tmp" "https://huggingface.co/buckets/{{HF_BUCKET}}/resolve/{{SHA_NAME}}"
	if [ -f "{{OUTPUT_DIR}}/{{ISO_NAME}}" ]; then
		EXPECTED_HASH=$(awk '{print $1}' "{{SHA_NAME}}.tmp")
		ACTUAL_HASH=$(sha256sum "{{OUTPUT_DIR}}/{{ISO_NAME}}" | awk '{print $1}')
		if [ "$EXPECTED_HASH" = "$ACTUAL_HASH" ]; then
			echo "==> ✅ Local ISO is up to date!"
		else
			echo "==> ⚠️  Local ISO is outdated!"
			echo "==> Please run: just download"
		fi
	else
		echo "==> ⚠️  Local ISO not found in {{OUTPUT_DIR}}!"
		echo "==> Please run: just download"
	fi
	rm -f "{{SHA_NAME}}.tmp"

# 2. Download the latest ISO and checksum from Hugging Face
# ⚠️ not tested yet..
download:
	#!/usr/bin/env bash
	set -e
	echo "==> Downloading latest ISO and checksum from Hugging Face..."
	mkdir -p "{{OUTPUT_DIR}}"
	curl -L -o "{{OUTPUT_DIR}}/{{ISO_NAME}}" "https://huggingface.co/buckets/{{HF_BUCKET}}/resolve/{{ISO_NAME}}"
	curl -L -o "{{OUTPUT_DIR}}/{{SHA_NAME}}" "https://huggingface.co/buckets/{{HF_BUCKET}}/resolve/{{SHA_NAME}}"
	echo "==> Download complete!"

# 3. Create a virtual disk for testing
disk:
	@echo "==> Creating virtual disk ({{DISK_SIZE}})..."
	@mkdir -p {{OUTPUT_DIR}}
	qemu-img create -f qcow2 {{OUTPUT_DIR}}/{{DISK_NAME}} {{DISK_SIZE}}

# [Internal] Build the cloud-init seed ISO from the local output cloud-init directory
[private]
_seed:
	@if [ ! -f {{SEED_ISO}} ]; then \
		echo "==> Setting up cloud-init files in {{CLOUD_INIT_SRC}}..."; \
		mkdir -p {{CLOUD_INIT_SRC}}; \
		if [ ! -f {{CLOUD_INIT_SRC}}/user-data ]; then \
			printf "#cloud-config\nusers:\n  - name: tester\n    sudo: ['ALL=(ALL) NOPASSWD:ALL']\n    shell: /bin/bash\n    lock_passwd: false\nchpasswd:\n  list: |\n    tester:password123\n  expire: False\n" > {{CLOUD_INIT_SRC}}/user-data; \
		fi; \
		if [ ! -f {{CLOUD_INIT_SRC}}/meta-data ]; then \
			printf "instance-id: penguinos-test-01\nlocal-hostname: penguinos-test\n" > {{CLOUD_INIT_SRC}}/meta-data; \
		fi; \
		echo "==> Packaging cloud-init seed ISO..."; \
		genisoimage -output {{SEED_ISO}} -volid cidata -joliet -rock {{CLOUD_INIT_SRC}}/; \
	fi

# 4. Install/Live-boot with test user cloud-init config
install: _seed
	@echo "==> Launching QEMU installer..."
	qemu-system-x86_64 \
		-enable-kvm \
		-m 4G \
		-smp 4 \
		-drive file={{OUTPUT_DIR}}/{{ISO_NAME}},media=cdrom \
		-drive file={{SEED_ISO}},media=cdrom \
		-drive file={{OUTPUT_DIR}}/{{DISK_NAME}},format=qcow2 \
		-boot d

# 5. Start the installed OS from the virtual disk
start:
	@echo "==> Starting PenguinOS..."
	qemu-system-x86_64 \
		-enable-kvm \
		-m 4G \
		-smp 4 \
		-drive file={{OUTPUT_DIR}}/{{DISK_NAME}},format=qcow2 \
		-net nic,model=virtio \
		-net user,hostfwd=tcp::2222-:22 \
		-display sdl

# 6. Destroy the testing disk, ISOs, and generated seed
destroy:
	@echo "==> Cleaning up test environment..."
	rm -rf {{OUTPUT_DIR}}/{{DISK_NAME}} {{OUTPUT_DIR}}/{{ISO_NAME}} {{OUTPUT_DIR}}/{{SHA_NAME}} {{SEED_ISO}} {{CLOUD_INIT_SRC}}
