#!/bin/bash

function showTableOfFS() {
  df -x sys -x proc -x tmpfs -x devtmpfs -H --output=target,source,fstype,size
}

function mountFS() {
  read -p "Enter the path to the file or device: " path

  if [ ! -b "$path" ] && [ ! -f "$path" ]; then
    echo "Invalid path specified!" >&2
    return 1
  fi

  read -p "Enter the mount path: " mountPath

  if [ ! -e "$mountPath" ]; then
    mkdir "$mountPath"
    if [ $? -ne 0 ]; then
      echo "Error creating directory!" >&2
      return 1
    fi
  fi

  if [ -d "$mountPath" ]; then
    if [ ! -z "$(ls "$mountPath")" ]; then
      echo "Directory is not empty!" >&2
      return 1
    fi
  else
    echo "This is not a directory!" >&2
  fi

  if [ -f "$path" ]; then
    device=$(losetup --find --show "$path")
    mkfs -t ext4 "$device"
    mount "$device" "$mountPath"
  else
    mount "$path" "$mountPath"
  fi

  if [ $? -ne 0 ]; then
    echo "Failed to mount" >&2
    return 1
  else
    echo "Mount successful" >&2
  fi

  mount | grep "$mountPath"
  return 0
}

function table() {
  local -n choos=$1
  choos+=("Help" "Exit")
  while true; do
    select opt in "${choos[@]}"; do
      case $opt in
        "Help")
          echo -e "Select a number"
          break
          ;;
        "Exit")
          return 0
          ;;
        *)
          if [ ! -z "$opt" ]; then
            return $REPLY
          else
            echo "Number should be from the list"
            break
          fi
          ;;
      esac
    done
  done
}

function unMountFS() {
  read -p "Enter the file system path: " path

  if [ ! -z "$path" ]; then
    umount "$path"
  else
    IFS=$'\n' read -r -d '' -a array < <(df -x proc -x sys -x devtmpfs -x tmpfs --output=target | tail -n+2 && echo -e '\0')
    table array
    ret=$?
    if [ $ret -eq 0 ]; then
      return 0
    fi
    umount "${array[ret-1]}"
    if [ $? -ne 0 ]; then
      echo 'Error' >&2
    else
      echo 'Successful'
    fi
  fi
}

function changeParams() {
  IFS=$'\n' read -r -d '' -a array < <(df -x proc -x sys -x devtmpfs -x tmpfs --output=target | tail -n+2 && echo -e '\0')
  echo -e "Enter the number you want to change\n"
  table array
  ret=$?
  if [ $ret -ne 0 ]; then
    path=${array[ret-1]}
  else
    echo -e "Error" >&2
    return
  fi
  echo -e "Select file system parameters: \n1. Read only\n2. Read and Write\n3. Exit\n\n"
  read -p "> " input
  case $input in
    1)
      mount -o remount,ro "$path"
      ;;
    2)
      mount -o remount,rw "$path"
      ;;
    3)
      exit
      ;;
    *)
      echo "Error"
      return 1
      ;;
  esac
}

function showFsParams() {
  read -p "Enter the file system path: " path

  if [ ! -z "$path" ]; then
    mount | grep "$path"
  else
    IFS=$'\n' read -r -d '' -a array < <(df -x proc -x sys -x devtmpfs -x tmpfs --output=target | tail -n+2 && echo -e '\0')
    table array
    ret=$?
    if [ $ret -eq 0 ]; then
      return 0
    fi
    mount | grep "${array[ret-1]}"
    if [ $? -ne 0 ]; then
      echo 'Error' >&2
    else
      echo 'Successful'
    fi
  fi
}

function showExtParams() {
  IFS=$'\n' read -r -d '' -a eArray < <(df -t ext2 -t ext3 -t ext4 -t extcow --output=source | tail -n+2)
  IFS=$'\n' read -r -d '' -a devicesArray < <(df -t ext2 -t ext3 -t ext4 -t extcow --output=source | tail -n+2 && echo -e '\0')

  echo "Enter the number: "

  table eArray

  ret=$?

  if [ $ret -ne 0 ]; then
    dev=${devicesArray[ret-1]}
  else
    echo "Error" >&2
    return 1
  fi

  tune2fs -l "$dev" | tail -n+2
}

if [ "$EUID" -ne 0 ]; then
  echo "Error! This program needs to be run with administrator privileges."
  exit
fi

if [ "$1" = "--help" ]; then
  echo -e "This program allows you to manage file systems.\nDeveloper: Your Name, Group XYZ"
  exit
fi

PS3='> '
options=("Show file system table" "Mount file system" "Unmount file system" "Change mount parameters of a mounted file system" "Show mount parameters of a mounted file system" "Show detailed information about ext* file system" "Exit")

while true; do
  select opt in "${options[@]}"; do
    case $opt in
      "Show file system table")
        showTableOfFS
        break
        ;;
      "Mount file system")
        mountFS
        break
        ;;
      "Unmount file system")
        unMountFS
        break
        ;;
      "Change mount parameters of a mounted file system")
        changeParams
        break
        ;;
      "Show mount parameters of a mounted file system")
        showFsParams
        break
        ;;
      "Show detailed information about ext* file system")
        showExtParams
        break
        ;;
      "Exit")
        exit
        ;;
      *)
        echo "Invalid option"
        ;;
    esac
  done
done
