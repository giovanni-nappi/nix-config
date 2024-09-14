SOPS_FILE := "../nix-secrets/secrets.yaml"

# qemu-system-x86_64 -hdd /tmp/vento.img -m 16G -netdev user,id=net0,hostfwd=tcp::8022-:22 -device virtio-net-pci,netdev=net0 -bios /nix/store/7a68vhgrwhp3i6lppv570111jmsb2mn2-OVMF-202402-fd/FV/OVMF.fd -daemonize

# default recipe to display help information
default:
  @just --list

rebuild-pre: update-nix-secrets
  git add *.nix

rebuild-post:
  just check-sops

# Add --option eval-cache false if you end up caching a failure you can't get around
rebuild: rebuild-pre
  scripts/system-flake-rebuild.sh

# Requires sops to be running and you must have reboot after initial rebuild
rebuild-full: rebuild-pre && rebuild-post
  scripts/system-flake-rebuild.sh

# Requires sops to be running and you must have reboot after initial rebuild
rebuild-trace: rebuild-pre && rebuild-post
  scripts/system-flake-rebuild-trace.sh

update:
  nix flake update

rebuild-update: update && rebuild

diff:
  git diff ':!flake.lock'

sops:
  echo "Editing {{SOPS_FILE}}"
  nix-shell -p sops --run "SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt sops {{SOPS_FILE}}"

age-key:
  nix-shell -p age --run "age-keygen"

rekey:
  cd ../nix-secrets && (\
    sops updatekeys -y secrets.yaml && \
    (pre-commit run --all-files || true) && \
    git add -u && (git commit -m "chore: rekey" || true) && git push \
  )
check-sops:
  scripts/check-sops.sh

update-nix-secrets:
  (cd ../nix-secrets && git fetch && git rebase) || true
  nix flake lock --update-input nix-secrets

iso:
  # If we dont remove this folder, libvirtd VM doesnt run with the new iso...
  rm -rf result
  nix build ./nixos-installer#nixosConfigurations.iso.config.system.build.isoImage

iso-install DRIVE: iso
  sudo dd if=$(eza --sort changed result/iso/*.iso | tail -n1) of={{DRIVE}} bs=4M status=progress oflag=sync

# creates a qemu raw disk
disk-create FILE SIZE:
  qemu-img create {{FILE}} {{SIZE}}

# runs a VM booting from ISO and using the DISK
iso-run DISK ISO MEM:
  qemu-system-x86_64 -cdrom {{ISO}} -hdd {{DISK}} -m {{MEM}} -netdev user,id=net0,hostfwd=tcp::8022-:22 -device virtio-net-pci,netdev=net0 -bios /nix/store/7a68vhgrwhp3i6lppv570111jmsb2mn2-OVMF-202402-fd/FV/OVMF.fd -daemonize

disko DRIVE PASSWORD:
  echo "{{PASSWORD}}" > /tmp/disko-password
  sudo nix --experimental-features "nix-command flakes" run github:nix-community/disko -- \
    --mode disko \
    disks/btrfs-luks-impermanence-disko.nix \
    --arg disk '"{{DRIVE}}"' \
    --arg password '"{{PASSWORD}}"'
  rm /tmp/disko-password

sync USER HOST:
  rsync -av --filter=':- .gitignore' -e "ssh -l {{USER}}" . {{USER}}@{{HOST}}:nix-config/

sync-secrets USER HOST:
  rsync -av --filter=':- .gitignore' -e "ssh -l {{USER}}" . {{USER}}@{{HOST}}:nix-secrets/
