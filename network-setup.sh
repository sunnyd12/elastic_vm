#!/bin/bash

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
image="Ubuntu1404"
scale_down_flavor="m1.test2"
user="ubuntu"

######Create Load balancer Pool#####
echo "Setting up Test Environment"
echo ""
echo "Creating Load balancer "
create_lb=$(heat stack-create load-balancer -f load-balancer.yaml)
sleep 5
echo ""
pool_id=$(neutron lb-pool-list| grep 'ACTIVE' | awk -F',' '{ print $0}'| awk '{print $2}') 
echo "Creating member"
heat stack-create scaledown -e environment-down.yaml -f lb-members.yaml -P "key_name=kp1;node_name=lb-member;node_server_flavor=$scale_down_flavor;node_image_name=$image;floating_net_id=$floating_net_id;private_net_id=$private_net_id;private_subnet_id=$private_subnet_id;pool_id=$pool_id"
echo ""
echo "Instance creation started at $((date)| grep -oP '\d+\:+\d+\:+\d+')"
sleep 30
echo "waiting for instance to boot up..."
sleep 1m 
neutron subnet-update $private_subnet_id --dns-nameservers list=true 8.8.8.8
echo ""
sleep 5
echo "Network set up ready"
exit

