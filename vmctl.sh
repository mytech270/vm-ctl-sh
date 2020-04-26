#!/bin/bash
#
# Filename:			  vmctl.sh
# Version:			  1.0
# Description:		Interface for quickly starting and halting multiple vagrant boxes
# Compatibility:	Tested on macOS Catalina 10.15.4, VirtualBox 6.1.6, and Vagrant 2.2.7
# Authors:		    Version 1.0 by James Flournoy and available on github.com

# Assign first argument if it exists
[ -z "$1" ] || vmctl_arg=$1

# Initialize counter, lists, and other variables
vm_count=0
vm_index=0
vm_id=()
vm_key=()
vm_name=()
vm_state=()
str_menu_format="%5s %15s %-15s\n"
is_digit='^[0-9]+$' # Regular expression for verifying input
 
# Import vm states into lists
function init_vm_list {
  echo
  echo "..Building virtual machine lists.."

  vm_list=$(vagrant global-status | awk '/virtualbox/{print $1 $4 $5}')
  for vm in $vm_list
  do
    # Incrementing the counter, and using it for the keypress value
    let "vm_count=vm_count+1"
   
    # Inserting / after the vm id so upcoming vm_state and vm_name assignments awk right 
    vm="${vm:0:7}/${vm:7}"
    
    # Populating each list for the vms
    vm_key+=("$vm_count")
    vm_id+=("${vm:0:7}")
    vm_state+=($(echo "$vm" | awk -F/ '{print $2}'))
    vm_name+=($(echo "$vm" | awk -F/ '{print $6}'))
  done
}

# Display header vmlists and get user action
function show_menu {
  clear
  show_header
  print_vm_list
  show_status_bar
  get_user_action  
  update_lists
}

# Display header
function show_header {
  echo
  echo "..VM Ctl Shell running in menu mode.."
  echo
  echo "Enter line number to change vm status such as vagrant up or halt"
  echo "Then enter c to commit changes or x exit without change: " commit_change
  echo
}  

# Prints vm list
function print_vm_list {
  printf "$str_menu_format" "Line" "vagrant box" "status" 
  printf "$str_menu_format" "-----" "---------------" "---------------" 
 
  for ((i=0; i<$vm_count; i++))
  do
    printf "$str_menu_format" "${vm_key[$i]}" "${vm_name[$i]}" "${vm_state[$i]}" 
  done
  echo 
}

# Show status
function show_status_bar {
  if [[ $commit_change =~ $is_digit ]] && [ "$commit_change" -le "$vm_count" ] && [ "$commit_change" -gt "0" ]; then
    echo ": $change_description ${vm_name[$vm_index]}"  
	echo
  else
    echo ": "
	echo
  fi
}

# Get user action
function get_user_action {
  read -p "vmctl> " commit_change

  if [ "$commit_change" == "C" ]; then commit_change="c"; fi
  if [ "$commit_change" == "X" ]; then commit_change="x"; fi
}

# Updated lists
function update_lists {
  if [[ $commit_change =~ $is_digit ]] && [ "$commit_change" -le "$vm_count" ] && [ "$commit_change" -gt "0" ]; then
    vm_index=$((commit_change - 1))
    case ${vm_state[$vm_index]} in
      "running")
        change_description="vagrant halt"
	    vm_state[$vm_index]="$change_description"
	    ;;  
	  "poweroff")
	    change_description="vagrant up"
	    vm_state[$vm_index]="$change_description"
	    ;;  
	  "vagrant up")
	    change_description="poweroff"
	    vm_state[$vm_index]="$change_description"
	    ;;  
	  "vagrant halt")
	    change_description="running"
	    vm_state[$vm_index]="$change_description"
	    ;;  
    esac
    show_menu
  elif [ "$commit_change" == "c" ]; then 
    apply_changes
  elif [ "$commit_change" == "x" ]; then
	exit_no_change
  else
    show_menu
  fi 
}

# Apply changes
function apply_changes {
  echo
  echo "..VM Ctl Shell applying changes.."
  echo
  for ((i=0; i<$vm_count; i++))
  do
    if [ "${vm_state[$i]}" == "vagrant up" ]; then
	  echo "Launching ${vm_name[$i]}"
	  vagrant up "${vm_id[$i]}"
	elif [ "${vm_state[$i]}" == "vagrant halt" ]; then
	  echo "Halting ${vm_name[$i]}"
	  vagrant halt "${vm_id[$i]}"
  fi
  done    
}

# Exit without change
function exit_no_change {
  echo
  echo "..VM Ctl Shell exiting with no changes.."
  echo
}

# Launch all boxes not currently running
function all_vm_up {
  read -p "Launch all vagrant boxes? Are you sure? [y/N]: " launch_confirmed
  if [ "$launch_confirmed" == "y" ] || [ "$launch_confirmed" == "Y" ]; then 
    init_vm_list
    for ((i=0; i<$vm_count; i++))
    do
      if [ "${vm_state[$i]}" == "poweroff" ]; then
        echo "Launching ${vm_name[$i]}"
        vagrant up "${vm_id[$i]}"
      fi
    done
  fi
}

# Halt all boxes currently running
function all_vm_halt {
  read -p "Halt all vagrant boxes. Are you sure. [y/N]: " halt_confirmed
  if [ "$halt_confirmed" == "y" ] || [ "$halt_confirmed" == "Y" ]; then 
    init_vm_list
    for ((i=0; i<$vm_count; i++))
    do
      if [ "${vm_state[$i]}" == "running" ]; then
        echo "Halting ${vm_name[$i]}"
        vagrant halt "${vm_id[$i]}"
	  fi
    done
  fi
}

# Main
function run_main {
  if [ -z "$vmctl_arg" ]; then 
    init_vm_list
    show_menu
  elif [ "$vmctl_arg" == "up" ]; then 
    all_vm_up
  elif [ "$vmctl_arg" == "halt" ]; then 
    all_vm_halt
  fi
}

run_main
