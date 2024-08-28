#!/bin/bash

#### Script to live-migrate all VMs from a Compute node for maintenance purposes ####

source /home/admin/rc/keystone.rc

echo "List of the Compute Nodes:"
openstack hypervisor list --insecure
openstack hypervisor list --insecure | awk 'NR > 3' | awk '{ print $4 }' | head -n 9 > ./hypervisor_hostname.txt

echo "Please enter a valid Compute host name from the above list"
read compute_name
CNexist=`grep -icx $compute_name ./hypervisor_hostname.txt`

while [ $CNexist -eq 0 ]
do
    echo -e "\e[1;91mError !!!\e[0m Please enter a correct Compute name from the list above."
    echo -e "Please choose a valid compute name. Ex: \e[96;1m1034398-compute048.localdomain\e[0m"
    read compute_name
    CNexist=`grep -icx $compute_name ./hypervisor_hostname.txt`
done

echo "List all VMs on marked compute node: "$compute_name
openstack server list --insecure --all-p --host $compute_name --long -c Name -c ID

VMs_count=$((`openstack server list --insecure --all-p --host $compute_name -c ID | awk 'NR > 3' | awk '{ print $2 }' | wc -l` - 1))
echo -e "Number of VMs on $compute_name is before evacuation \e[93;1m$VMs_count\e[0m"
echo
echo -e "\e[1;91mPLEASE DON'T EVACUATE COMPUTE NODE IF IT HAS CELLCOM SCP VM, SUCH ACTION MUST BE PRE-ARRANGED WITH THE CUSTOMER\e[0m"
echo
# Function to migrate all VMs on choosed compute node
evacuate_compute () {
echo -e "Would you like to start migrating all VMs on \e[96;1m$compute_name\e[0m ? Enter \e[1;92myes\e[0m/\e[1;91mno\e[0m"
read user_input

if [ $user_input == "yes" ]
then

     # Saving VMs ID in a file to be used by migration command
     openstack server list --insecure --all-p --host $compute_name -c ID | awk 'NR > 3' | awk '{ print $2 }' | head -n $VMs_count > ./VMs_ID.txt
     # Saving VMs Info in a file before evacuation
     openstack server list --insecure --all-p --host $compute_name -c Name -c ID | awk 'NR > 3' | awk '{ print $2 "   " $4 }' > ./VMs_info.txt
     
     echo -e "\e[93;1mSTARTING EVACUATION OPERATION\e[0m"
     echo
     
     for vm in $(cat ./VMs_ID.txt)
     do
          echo "Source compute node is $compute_name"
          echo 
          echo -e "Migrating of \e[96;1m$vm\e[0m is Running........................."
          openstack --insecure --os-compute-api-version 2.30 server migrate --live-migration $vm --wait
          dest_compute=`openstack server show $vm | grep hypervisor_hostname | awk -F"|" '{print$3}' | awk -F" " '{print $1}'`
          echo -e "Destination compute node is \e[1;92m$dest_compute\e[0m"
          openstack server show $vm > ./VM_state.txt
          vm_status=`grep -c ACTIVE ./VM_state.txt`
          echo 
          if [ $compute_name != $dest_compute ]
          then               
               if [ $vm_status -eq 1 ]
               then
                    echo -e "Migration of $vm has \e[1;92msucceeded\e[0m and it's in \e[1;92mACTIVE\e[0m status"
                    echo "#########################################################################################"
               else
                    echo -e "\e[1;91m$vm was migrated but not in ACTIVE state\e[0m"
               fi
          else
               echo -e "Migration of $vm has \e[1;91mfailed\e[0m"
               echo "##############################################################################################"
          fi     
     done

     echo
     pre_migrate=$((`openstack server list --insecure --all-p --host $compute_name -c ID | awk 'NR > 3' | awk '{ print $2 }' | wc -l`))
     echo -e "Number of VMs on $compute_name after evacuation is \e[93;1m$pre_migrate\e[0m"
     openstack --insecure server list --all-p --host $compute_name --long -c Name -c ID

elif [ $user_input == "no" ]
then
     echo "Aborting script!"
     exit
else
     # To make sure that user's answer can be just yes or no
     evacuate_compute
fi
}

# Calling evacuation function
evacuate_compute

echo -e "\e[1;92mEVACUATION OPERATION HAS BEEN COMPLETED!\e[0m"
