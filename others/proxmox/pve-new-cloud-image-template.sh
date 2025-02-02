#!/bin/bash
#set -x

#
## basic information:
## |__ This script downloads latest Ubuntu cloud image and creates a VM template
#
## location: Proxmox VE
#
## documentation:
## |__ https://gist.github.com/chriswayg/b6421dcc69cb3b7e41f2998f1150e1df
## |__ https://pve.proxmox.com/pve-docs/qm.1.html
#

echo "# Start script - $(date)"

# check if the script is run as root
if [ "$(id -u)" -ne 0 ]; then
    echo "|__ Please run as root"
    echo "# End script - $(date)"
    exit 1
fi

# set parameters
# v22.04 LTS
#CLOUD_IMAGE_URI='https://cloud-images.ubuntu.com/jammy/current'
#CLOUD_IMAGE_NAME='jammy-server-cloudimg-amd64.img'

# v24.04 LTS
CLOUD_IMAGE_URI='https://cloud-images.ubuntu.com/noble/current/'
CLOUD_IMAGE_NAME='noble-server-cloudimg-amd64.img'

CLOUD_IMAGE_URL="$CLOUD_IMAGE_URI/$CLOUD_IMAGE_NAME"

# set template parameters
VM_TEMPLATE_ID=9000
VM_TEMPLATE_NAME='int-tmpl-ubuntu-2404'
VM_STORAGE_NAME='local_ssd_1tb'

# set local paths
LOCAL_ISO_PATH="/mnt/pve/$VM_STORAGE_NAME/template/iso"
LOCAL_SNIPPETS_PATH='/var/lib/vz/snippets'
if [ ! -d "$LOCAL_SNIPPETS_PATH" ]; then
    mkdir -p "$LOCAL_SNIPPETS_PATH"
fi
LOCAL_GUEST_AGENT_SNIPPET="$LOCAL_SNIPPETS_PATH/qemu-guest-agent.yml"

# Get hash
echo "# Download latest cloud image hash..."
CLOUD_IMAGE_HASH=$(curl --silent "$CLOUD_IMAGE_URI/SHA256SUMS" | grep $CLOUD_IMAGE_NAME | awk '{print $1}')
LOCAL_IMAGE_HASH=$(sha256sum "$LOCAL_ISO_PATH/$CLOUD_IMAGE_NAME" | awk '{print $1}')

if [ "$CLOUD_IMAGE_HASH" == "$LOCAL_IMAGE_HASH" ]; then
    echo "|__ Latest image already in use"
    echo "# End script - $(date)"
    exit 0
else
    echo "|__ New image available"
fi

{
    cd "$LOCAL_ISO_PATH"

    # remove old cloud image
    if [ -f "$CLOUD_IMAGE_NAME" ]; then
        echo "# Remove old cloud image..."
        rm "$CLOUD_IMAGE_NAME"
        echo "|__ Removed successfully"
    fi

    # Download the cloud image
    echo "# Download latest cloud image..."
    echo
    echo
    wget "$CLOUD_IMAGE_URL"
    echo
    echo
    echo "|__ Downloaded successfully"

    # Destroy old template
    if qm status $VM_TEMPLATE_ID | grep -q "status: running"; then
        echo "# Stop the VM..."
        qm stop $VM_TEMPLATE_ID
        echo "|__ VM stopped successfully"
    fi

    if qm status $VM_TEMPLATE_ID | grep -q "status: stopped"; then
        echo "# Destroy the VM..."
        qm destroy $VM_TEMPLATE_ID --purge true
        echo "|__ VM destroyed successfully"
    else
        echo "|__ VM not stopped"
        exit 1
    fi

    # Create a VM
    echo "# Create a VM..."
    qm create $VM_TEMPLATE_ID --name $VM_TEMPLATE_NAME --ostype l26 --bios ovmf --boot "order=scsi0;ide2;net0" --hotplug network,disk,usb --scsihw virtio-scsi-pci --agent 1 --sockets 1 --cores 2 --memory 4096 --balloon 1024 --net0 virtio,bridge=vmbr0,firewall=1 --pool pool_linux
    echo "|__ VM created successfully"

    # Import the disk in qcow2 format (as unused disk)
    echo "# Import the disk in qcow2 format..."
    qm importdisk $VM_TEMPLATE_ID $CLOUD_IMAGE_NAME $VM_STORAGE_NAME -format qcow2
    echo "|__ Disk imported successfully"

    # Attach the disk to the vm using VirtIO SCSI
    echo "# Attach the disk to the vm..."
    qm set $VM_TEMPLATE_ID --scsi0 file=/mnt/pve/$VM_STORAGE_NAME/images/$VM_TEMPLATE_ID/vm-$VM_TEMPLATE_ID-disk-0.qcow2,backup=1,cache=writeback,discard=on,iothread=1,replicate=1,ssd=1
    echo "|__ Disk attached successfully"

    # Set cloud init storage
    echo "# Set cloud init storage..."
    qm set $VM_TEMPLATE_ID --ide2 $VM_STORAGE_NAME:cloudinit
    echo "|__ Cloud init storage set successfully"

    # The initial disk is only 2GB, thus we make it larger
    # echo "# Resize the template disk..."
    # qm resize $VM_TEMPLATE_ID scsi0 +30G
    # echo "|__ Disk resized successfully"

    # Using a dhcp server on vmbr0 or use static IP
    # echo "# Set network configuration..."
    # qm set $VM_TEMPLATE_ID --ipconfig0 ip=dhcp
    # qm set $VM_TEMPLATE_ID --ipconfig0 ip=10.10.10.222/24,gw=10.10.10.1
    # echo "|__ Network configuration set successfully"

    # user authentication for 'ubuntu' user (optional password)
    # echo "# Set user authentication..."
    # qm set $VM_TEMPLATE_ID --sshkey ~/.ssh/id_rsa.pub
    # qm set $VM_TEMPLATE_ID --cipassword AweSomePassword
    # echo "|__ User authentication set successfully"

    # check cloud-init config
    # echo "# Show cloud-init config..."
    # qm cloudinit dump $VM_TEMPLATE_ID user
    # echo "|__ Export cloud-init config successfully"

    # create template
    echo "# Create template..."
    qm template $VM_TEMPLATE_ID
    echo "|__ Template created successfully"

    # create snippet: qemu-guest-agent
    echo "# Create snippet: qemu-guest-agent..."
    if [ -f "$LOCAL_GUEST_AGENT_SNIPPET" ]; then
        echo "|__ Snippet already exists"
    else
        echo -e "#cloud-config\nruncmd:\n    - apt update\n    - apt -y upgrade && apt -y autoremove && apt -y autoclean\n    - apt install -y qemu-guest-agent\n    - systemctl enable qemu-guest-agent\n    - systemctl start qemu-guest-agent\n    - reboot" > "$LOCAL_GUEST_AGENT_SNIPPET"
        echo "|__ Snippet created successfully"
    fi

    echo
    echo "# End script - $(date)"
} || { # catch any necessary errors to prevent the program from improperly exiting.
    ExitCode=$?

    if [ $ExitCode -ne 0 ]; then
        echo "# Error: Script failed with error code: $ExitCode"
        echo "# End script - $(date)"
        exit $ExitCode
    fi
}
