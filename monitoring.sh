#!/bin/bash
COUNT="5"
var="100"
user="ubuntu"
scale_up1="scaleup1"
scale_up2="scaleup2"
scale_down="scaledown"
scale_up1_flavor="m1.small"
scale_up2_flavor="m1.test2"
scale_down_flavor="m1.test2"
image="Ubuntu1404"


#####Environment Parameters#######
export OS_AUTH_URL=http://192.168.1.231:5000/v2.0
export OS_TENANT_ID=2d7d88a637f146d2a3a9155eda881a74
export OS_TENANT_NAME="demo"
export OS_USERNAME="demo"
export OS_PASSWORD="stack"
export OS_REGION_NAME="RegionOne"

floating_net_id=$(neutron net-list | grep 'public' | awk -F',' '{ print $0}' | awk '{print $2}')
private_net_id=$(neutron net-list | grep 'private' | awk -F',' '{ print $0}' | awk '{print $2}')
private_subnet_id=$(neutron net-list | grep 'private' | awk -F',' '{ print $0}' | awk '{print $6}')

#######Receive info ############

function active_instance {
  vm_ip=$(neutron lb-member-list | grep 'ACTIVE' | awk -F',' '{ print $1}' | awk '{print $4}' | sed -n 1p)
  vm_ip2=$(neutron lb-member-list | grep 'ACTIVE' | awk -F',' '{ print $1}' | awk '{print $4}' | sed -n 2p)

  vm_id=$(nova list | grep 'ACTIVE' | awk -F',' '{ print $1}' | awk '{print $2}'| sed -n 1p)
  vm_id2=$(nova list | grep 'ACTIVE' | awk -F',' '{ print $1}' | awk '{print $2}'| sed -n 2p)
  nova show $vm_id | grep 'OS-SRV-USG:launched_at'
  pool_id=$(neutron lb-pool-list | grep 'haproxy' | awk -F',' '{ print $0}'| awk '{print $2}')
  vm_membership_id=$(neutron lb-member-list | grep 'ACTIVE' | awk -F',' '{ print $1}' | awk '{print $2}' | sed -n 1p)
  if [ -z "$vm_ip2" ];then
    echo "Active Server......"$vm_ip $vm_id
    echo ""
#    echo "Active Instance ID......"$vm_id
#    echo ""
  else
    echo  "Active Servers......." 
    echo ""
    echo $vm_ip $vm_id
    echo ""
    echo $vm_ip2 $vm_id2
  fi
#  exit
  }

function ping_test {
  packet_losscount_vm=$(ping -c 5 $vm_ip | grep -oP '\d+(?=% packet loss)' | awk -F',' '{ print $0}')
#  echo "Packet loss from $vm_ip is $packet_losscount_vm % "
#  exit
  }

function ram_usage {
#  used_ram=$(ssh -i my-private-key.txt $user@$vm_ip free -m | grep "Mem:" | awk '{ print $3}')
#  total_ram=$(ssh -i my-private-key.txt $user@$vm_ip free -m | grep "Mem:" | awk '{ print $2}')
  echo "Checking RAM in use..."
#  sleep 5
  total_ram=$(ssh -i my-private-key.txt -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o LogLevel=quiet  $user@$vm_ip free -m | grep "Mem:" | awk '{ print $2}')
  used_ram=$(ssh -i my-private-key.txt -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o LogLevel=quiet  $user@$vm_ip free -m | grep "Mem:" | awk '{ print $3}')
  used_ram_time=$(date)
#  echo $total_ram
#  echo $used_ram
  mem_usage_vm=$(( $used_ram*100 / $total_ram ))
#  mem_usage_vm=$(ssh -i my-private-key.txt $user@$vm_ip free -m | grep "Mem:" | awk '{ print $3}')
  echo "RAM in use $mem_usage_vm % at $used_ram_time"
#  exit
  }

function cpu_usage {
  echo "Checking CPU in use..."
  cpu_usage_vm_idle=$(ssh -i my-private-key.txt -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o LogLevel=quiet $user@$vm_ip top -b -n 5| grep 'Cpu' | awk -F',' '{ print $0}' | awk {'print $8'} | sed -n 5p | awk '{printf "%.0f\n", $1}')
#  echo $cpu_usage_vm_idle
  cpu_usage_time=$(date) 
  cpu_usage_vm=$(( $var - $cpu_usage_vm_idle ))
#  cpu_usage_vm=$(ssh -i my-private-key.txt -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o LogLevel=quiet $user@$vm_ip top -b -n 5| grep 'Cpu' | awk -F',' '{ print $0}' | awk {'print $2'} | sed -n 5p | awk '{printf "%.0f\n", $1}')

  echo "CPU in use $cpu_usage_vm % at $cpu_usage_time"
#  exit
  }

function top_usage {
  top_usage=$(ssh -i my-private-key.txt -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o LogLevel=quiet ubuntu@$vm_ip top -b -n 3 -d 1 | grep -w 'days\|Cpu\|KiB Mem' | awk -F',' '{ print $0}' | sed -n -e 1,9p)
  cpu_usage
  ram_usage
  exit
  }

################Scaling functions########################

function scaledown {
  existing_stack_scaleup2=$(heat stack-list | grep 'scaleup2' | awk -F',' '{ print $0}' | awk '{print $4}')
  existing_stack_scaleup1=$(heat stack-list | grep 'scaleup1' | awk -F',' '{ print $0}' | awk '{print $4}')
  existing_stack_server=$(heat stack-list | grep 'server' | awk -F',' '{ print $0}' | awk '{print $4}')
  existing_stack_scaledown=$(heat stack-list | grep 'scaledown' | awk -F',' '{ print $0}' | awk '{print $4}')
  if [[ "$existing_stack_scaleup2" == "scaleup2" ]]; then
    echo "Scaling down parallel ..."
    echo "Stack deletion started at $(date)"
    del3=$(heat stack-delete scaleup2)
    echo "Scale down completed at .....$((date)| grep -oP '\d+\:+\d+\:+\d+')" 
  elif [[ "$existing_stack_scaleup1" == "scaleup1" ]]; then
    echo "Scaling down..."
    stack_create=$(heat stack-create scaledown -e environment_down.yaml -f lb-members.yaml -P "key_name=kp1;node_name=lb-member;node_server_flavor=$scale_down_flavor;node_image_name=$image;floating_net_id=$floating_net_id;private_net_id=$private_net_id;private_subnet_id=$private_subnet_id;pool_id=$pool_id") 
    echo "Stack creation done at $(date)"
    sleep 4m
    echo "Stack deletion started at $(date)"
    del2=$(heat stack-delete scaleup1)
    echo "Scale down completed at .....$((date)| grep -oP '\d+\:+\d+\:+\d+')" 
  elif [[ "$existing_stack_server" == "server" ]]; then
    echo "Scaling down..."
    stack_create=$(heat stack-create scaledown -e environment_down.yaml -f lb-members.yaml -P "key_name=kp1;node_name=lb-member;node_server_flavor=$scale_down_flavor;node_image_name=$image;floating_net_id=$floating_net_id;private_net_id=$private_net_id;private_subnet_id=$private_subnet_id;pool_id=$pool_id")
    echo "Stack creation done at $(date)"
    sleep 4m
    echo "Stack deletion started at $(date)"
    del1=$(heat stack-delete server)
    echo "Scale down completed at .....$((date)| grep -oP '\d+\:+\d+\:+\d+')" 
  elif [[ "$existing_stack_scaledown" == "scaledown" ]]; then
    echo "Already lowest flavor...scaling down not possible"
  else
    echo "Scaledown not required"
  fi
  }


### add a bigger image and replace the old one
function scaleup {
  existing_stack_scaleup1=$(heat stack-list | grep 'scaleup1' | awk -F',' '{ print $0}' | awk '{print $4}')
  existing_stack_scaleup2=$(heat stack-list | grep 'scaleup2' | awk -F',' '{ print $0}' | awk '{print $4}')
  existing_stack_scaledown=$(heat stack-list | grep 'scaledown' | awk -F',' '{ print $0}' | awk '{print $4}')
  if [[ "$existing_stack_scaleup2" == "scaleup2" ]]; then
    echo "Quota full scale up operation not possible"
  elif [[ "$existing_stack_scaleup1" == "scaleup1" ]]; then
    echo "Vertical scaling not possible...parallel scaling in progress..."
    stack_create=$(heat stack-create scaleup2 -e environment_up.yaml -f lb-members.yaml -P "key_name=kp1;node_name=lb-member;node_server_flavor=$scale_up2_flavor;node_image_name=$image;floating_net_id=$floating_net_id;private_net_id=$private_net_id;private_subnet_id=$private_subnet_id;pool_id=$pool_id")
    echo "Scaleup completed .....at $((date)| grep -oP '\d+\:+\d+\:+\d+')"
  elif [[ "$existing_stack_server" == "server" ]]; then
    echo "Scaling up ..."
    stack_create=$(heat stack-create scaleup1 -e environment_up.yaml -f lb-members.yaml -P "key_name=kp1;node_name=lb-member;node_server_flavor=$scale_up1_flavor;node_image_name=$image;floating_net_id=$floating_net_id;private_net_id=$private_net_id;private_subnet_id=$private_subnet_id;pool_id=$pool_id")
    echo "Stack creation done at $(date)"
    sleep 4m
    echo "Stack deletion started at $(date)"
    del1=$(heat stack-delete server)
    echo "Scaleup completed .....at $((date)| grep -oP '\d+\:+\d+\:+\d+')"
  elif [[ "$existing_stack_scaledown" == "scaledown" ]]; then
    echo "Scaling up ..."
    stack_create=$(heat stack-create scaleup1 -e environment_up.yaml -f lb-members.yaml -P "key_name=kp1;node_name=lb-member;node_server_flavor=$scale_up1_flavor;node_image_name=$image;floating_net_id=$floating_net_id;private_net_id=$private_net_id;private_subnet_id=$private_subnet_id;pool_id=$pool_id")
    echo "Stack creation done at $(date)"
    sleep 4m
    echo "Stack deletion started at $(date)"
    del2=$(heat stack-delete scaledown)
    echo "Scaleup completed .....at $((date)| grep -oP '\d+\:+\d+\:+\d+')"
  else 
    echo "No conditions to fulfill"
  fi
  }


################## Monitoring ##############################
while true; do
  clear
  echo "Checking performance ..."
  echo "considering CPU and RAM usage"
  echo ""
  active_instance
  ping_test
  ram_usage
  cpu_usage
#  if [[ "$cpu_usage_vm" -gt 30 && "$mem_usage_vm" -gt 50 ]]; then
  if [[ "$cpu_usage_vm" -ge 80 && "$mem_usage_vm" -ge 80 ]]; then
    echo "Scaleup required ...as CPU usaage: $cpu_usage_vm % RAM usage: $mem_usage_vm % is high"
    echo "Initiating operation at $((date)| grep -oP '\d+\:+\d+\:+\d+')"
    scaleup
#    if [[ "$cpu_usage_vm" -gt 70 && "$mem_usage_vm"  -gt 50 ]]; then
#      echo "scaleup2"
#    elif [[ "$cpu_usage_vm" -gt 50 || "$mem_usage_vm"  -gt 50 ]]; then
#      echo  "scaleup1"
#      scaleup
#    else
#      echo "Status: HEALTHY"
#    fi
  else
    if [[ "$cpu_usage_vm" -le 20 && "$mem_usage_vm" -le 40 ]]; then
      echo ""
      echo "Scaledown required ...as CPU usaage: $cpu_usage_vm % RAM usage: $mem_usage_vm % is low"
      echo "Initiating operation at $((date)| grep -oP '\d+\:+\d+\:+\d+')"
      scaledown
    else
      echo "Resource usage status: HEALTHY"
    fi
  fi
  echo ""
#  echo "Monitoring will resume in 30 seconds"
  sleep 10
  active_instance
  ram_usage
  cpu_usage
  sleep 20
  echo "Monitoring will resume in 30 seconds"
  sleep 30 
  echo "."
done



