#!/bin/bash

#echo "Hello world"
user="ubuntu"


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
vm_ip=$(neutron lb-member-list | grep 'ACTIVE' | awk -F',' '{ print $1}' | awk '{print $4}' | sed -n 1p)
vm_id=$(nova list | grep 'ACTIVE' | awk -F',' '{ print $1}' | awk '{print $2}'| sed -n 1p)

#lb_pool_list=$(neutron lb-pool-list | grep 'haproxy' | awk -F',' '{ print $1}' | awk '{print $2}')
#lb_vip_id=$(neutron lb-pool-show $lb_pool_list | grep 'vip_id' | awk -F',' '{ print $0}' | awk '{print $4}')
#neutron lb-vip-show
#neutron floatingip-list

lb_local_ip=$(neutron lb-vip-list | grep 'HTTP' | awk -F',' '{ print $0}' | awk '{print $6}')
load_balancer_floating_ip=$(neutron floatingip-list | grep $lb_local_ip | awk -F',' '{ print $0}' | awk '{print $6}')

############## Fetch data ##############
# Get top usage
rm /home/stack/devstack/dataout/top_out.txt
#ssh -i my-private-key-2.txt -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o LogLevel=quiet ubuntu@$vm_ip << EOF
#for n in {1..650000}; do ssh -i my-private-key-2.txt -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o LogLevel=quiet ubuntu@$vm_ip top -b -n5 -d 1 | sed -n 1,5p >> /home/stack/stream/top_out.txt; done
for i in {1..600}; do ssh -i my-private-key.txt -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o LogLevel=quiet ubuntu@$vm_ip top -b -n 3 -d 1 | grep -w 'days\|Cpu\|KiB Mem' | awk -F',' '{ print $0}' | sed -n -e 1,9p; done >> /home/stack/devstack/dataout/top_out.txt
echo "top data complete"
exit
