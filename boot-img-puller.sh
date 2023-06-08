#!/bin/bash

# Check for root privileges
if [ "$(whoami)" != "root" ]; then
  echo "Error: Insufficient privileges"
  echo "Please run this script as root."
  exit 1
fi

# Print a header message
echo "########################################"
echo "#    Boot Image Puller for Android     #"
echo "#         Developed by Abhijeet        #"
echo "########################################"
echo ""

echo "Finding the boot slots partition location..."
sleep 5

# Find the path to the by-name directory
by_name_path=$(find /dev/block/platform -type d -name by-name)

# Check if the directory was found
if [ -z "$by_name_path" ]; then
  echo ""
  echo "Error: Partition location not found"
  echo ""
  echo "Reason: Unable to locate the 'by-name' directory in '/dev/block/platform'."
  exit 1
fi

# Check if the device has A/B slots by reading the slot suffix property
check_slot=$(getprop ro.boot.slot_suffix)

if [[ -n "$check_slot" ]]; then
  # Dual-slot device
  device_type="dual_slot"
  boot_a_symlink="$by_name_path/boot_a"
  boot_b_symlink="$by_name_path/boot_b"

  if [[ ! -e "$boot_a_symlink" || ! -e "$boot_b_symlink" ]]; then
    echo ""
    echo "Error: Partition location not found"
    echo ""
    echo "Reason: Neither 'boot_a' nor 'boot_b' symbolic file exists in the '/dev/block/platform' by-name directory."
    exit 1
  fi

  # Find the actual paths of boot_a and boot_b partitions
  boot_a_path=$(readlink -f "$boot_a_symlink" 2>/dev/null)
  boot_b_path=$(readlink -f "$boot_b_symlink" 2>/dev/null)

  if [[ -z "$boot_a_path" || -z "$boot_b_path" ]]; then
    echo ""
    echo "Error: Partition location not found"
    echo ""
    echo "Reason: Unable to find both symlink's actual paths."
    exit 1
  fi

  echo ""
  echo "Your device has A/B slots"
  echo ""
  echo "boot_a partition location: $boot_a_path"
  echo ""
  echo "boot_b partition location: $boot_b_path"
else
  # Single-slot device
  device_type="single_slot"
  boot_symlink="$by_name_path/boot"

  if [[ ! -e "$boot_symlink" ]]; then
    echo ""
    echo "Error: Partition location not found"
    echo ""
    echo "Reason: Unable to find the 'boot' symbolic file in the '/dev/block/platform' by-name directory."
    exit 1
  fi

  # Find the actual path of the boot partition
  boot_path=$(readlink -f "$boot_symlink" 2>/dev/null)

  if [[ -z "$boot_path" ]]; then
    echo ""
    echo "Error: Partition location not found"
    echo ""
    echo "Reason: Unable to find the 'boot' symbolic link's actual path."
    exit 1
  fi

  echo ""
  echo "Your device has a single slot"
  echo ""
  echo "boot partition location: $boot_path"
fi

# Function to pull the boot image for a dual-slot device
pull_boot_image_dual_slot() {
  local boot_a_path=$1
  local boot_b_path=$2

  # Set both boot partitions to read-write
  blockdev --setrw "$boot_a_path"
  blockdev --setrw "$boot_b_path"

  # Check the current active slot
  active_slot=$(getprop ro.boot.slot_suffix)

  # Display a warning message
  echo ""
  echo "It is recommended to pull the boot image according to the current active slot, which is ($active_slot)."
  echo ""

  # Loop until valid input is provided
  while true; do
    # Ask the user to choose the boot slot image
    read -r -p "Which boot slot image would you like to pull? (a/b): " chosen_slot

    # Determine the boot image path based on the chosen slot
    case $chosen_slot in
      a)
        boot_image_path="$boot_a_path"
        break
        ;;
      b)
        boot_image_path="$boot_b_path"
        break
        ;;
      *)
        echo "Invalid input. Please choose either 'a' or 'b'."
        ;;
    esac
  done

  # Pull the boot image using dd with pv for progress monitoring
  echo "Pulling the boot image from $boot_image_path..."
  if dd if="$boot_image_path" of="./boot$active_slot.img"; then
    echo ""
    echo "Boot image pulled successfully and saved to the $(pwd) directory."
  else
    echo ""
    echo "Error: Failed to pull the boot image."
    exit 1
  fi
}

# Function to pull the boot image for a single-slot device
pull_boot_image_single_slot() {
  local boot_path=$1

  # Set the boot partition to read-write
  blockdev --setrw "$boot_path"

  # Pull the boot image using dd with pv for progress monitoring
  echo "Pulling the boot image from $boot_path..."
  if dd if="$boot_path" of="./boot.img"; then
    echo ""
    echo "Boot image pulled successfully and saved to the $(pwd) directory."
  else
    echo ""
    echo "Error: Failed to pull the boot image."
    exit 1
  fi
}

# Pull the boot image according to the slot type
if [ "$device_type" = "dual_slot" ]; then
  pull_boot_image_dual_slot "$boot_a_path" "$boot_b_path"
elif [ "$device_type" = "single_slot" ]; then
  pull_boot_image_single_slot "$boot_path"
fi

exit 0