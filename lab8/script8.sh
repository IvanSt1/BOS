#!/bin/bash

error_log() {
  echo "[$(date +'%Y-%m-%dT%H:%M:%S')]: $*" >&2
}

if [ "$EUID" -ne 0 ]; then
	echo "Script is accessible only for root user"
	exit
fi

PS3='> '
options_script=(
         "Search system services"
         "Display process list and their services"
         "Manage services"
         "Search in journal"
         "Exit"
       )

option_list() {
  local -n opt_list=$1
  opt_list+=(
            "Help"
            "Exit"
            ) 
  while true
  do
  select choice in "${opt_list[@]}"; do
    case $choice in
      "Help")
        echo $2
        break
        ;;
      "Exit")
        return 0
        ;;
      *)
        if [ -z "$choice" ]; then
          error_log "Please enter a number from the list"
          break
        else
          return $REPLY
        fi
        ;;
      esac
    done
  done
}

output_handler() {
  if [ $1 -ne 0 ]; then
    error_log $3
    return
  else
    echo $2
  fi
}

output_less_than_ten() {
  if [ $(wc -l <<< "$1") -lt 10 ]; then
    echo "$1"
  else
    less <<< "$1"
  fi
}

if [ "$1" = "-help" ]; then
  echo "This script lets you manage services and logs."
  exit
fi

search_services() {
  read -p "Enter the name of the service or part of it: " service_name
  output_less_than_ten "$(systemctl list-units --type=service | head -n-6 | tail -n+2 | grep "$service_name")"
}

display_processes_services() {
  output_less_than_ten "$(ps ax -o'pid,unit,args' | grep  '.service')"
}

search_journal() {
  read -p "Service name or part of it: " service
  read -p "Importance level: " priority
  read -p "Search string: " req
  journalctl -p "$priority" -u "$service" -g "$req"
}

service_management() {
  IFS=$'\n' read -r -d '' -a arr < <(systemctl list-units --type=service | head -n-6 | tail -n+2 | cut -c 3- |  cut -d" " -f 1 && printf '\0')
  option_list arr "Service number: "
  service_num=$?
  echo "========" $service_num
  if [ $service_num -eq 0 ]; then
    return
  fi
  service=${arr[service_num-1]}
  service_options=(
          "Enable service"
          "Disable service"
          "Start or restart service"
          "Stop service"
          "Show service unit content"
          "Edit service unit"
          "Back"
  )
  select choice in "${service_options[@]}"
  do
    case $choice in
      "Enable service")
      systemctl enable "$service"
      break
      ;;
      "Disable service")
      systemctl disable "$service"
      break
      ;;
      "Start or restart service")
      systemctl restart "$service"
      break
      ;;
      "Stop service")
      systemctl stop "$service"
      break
      ;;
      "Show service unit content")
      less "$(systemctl status $service | head -n+2 | tail -n-1 | cut -f2 -d"(" | cut -f1 -d";")"
      break
      ;;
      "Edit service unit")
        vim "$(systemctl status $service | head -n+2 | tail -n-1 | cut -f2 -d"(" | cut -f1 -d";")"
      break
      ;;
      "Back")
      return
      ;;
      *) error_log "Invalid argument $REPLY"
      esac
    done 
}

while true
do
select choice in "${options_script[@]}"
do
  case $choice in
    "Search system services")
      search_services
      break
      ;;
    "Display process list and their services")
      display_processes_services
      break
      ;;
    "Manage services")
      service_management
      break
      ;;
    "Search in journal")
      search_journal
      break
      ;;
    "Exit")
      exit
      ;;
    *) error_log "Invalid argument $REPLY"
  esac
done
done
