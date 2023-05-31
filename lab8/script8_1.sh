#!/bin/bash

service_units=$(systemctl list-units --type=service | head -n-6 | tail -n+2 | cut -c 3- |  cut -d" " -f 1)

for unit in $service_units; do
  access_rights=$(gerfacl $unit  2>/dev/null | grep -v -E "^#" | grep -v "user::" | grep -E ":.w.$")
  unit_file=$(systemctl status $unit | head -n+2 | tail -n-1 | cut -f2 -d"(" | cut -f1 -d";")
  user_name=$(grep "User=" "$unit_file") 
  if [ ! -z "$access_rights" ]; then
    echo "$unit has $unit_file with the following permissions: $access_rights"
  fi
  IFS=$'\n' read -r -d '' -a exe_cmds < <(grep -E "(ExecStart|ExecStartPre|ExecStartPost|ExecReload|ExecStop|ExecStopPost)=" "$unit_file" && printf '\0')

  for cmd in "${exe_cmds[@]}"; do
    exe_file=$(cut -f1 -d" " <<< "${cmd#*=}")
    exe_file="${exe_file/#-/}"
    exe_permissions=$(getfacl $exe_file 2>/dev/null | grep -v -E "^#" | grep -v "user::" | grep -E ":.w.$")
    if [ ! -z $exe_permissions ]; then
      echo "$unit has $unit_file with the following permissions: $exe_permissions"
    fi

    if [ ! "$user_name" = "User=root" ]; then
      owner_name=$(stat -c '%U' "$exe_file" 2>/dev/null)
      if [ "$owner_name" = "root" ]; then
        if stat -L -c '%A' "$exe_file" | grep -q "s"; then
          echo "$unit is run under $user_name ,but has $unit_file with suid, guid owned by root"
        fi
      fi
    fi
  done
done
