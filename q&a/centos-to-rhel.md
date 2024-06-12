# CentOS to RHEL

[How to convert CentOS Linux to Red Hat Enterprise Linux on Azure](https://techcommunity.microsoft.com/t5/linux-and-open-source-blog/how-to-convert-centos-linux-to-red-hat-enterprise-linux-on-azure/ba-p/3960735)

[Convert2RHEL: Move to Red Hat Enterprise Linux from other Linux distros](https://www.redhat.com/en/technologies/linux-platforms/enterprise-linux/migration-process/convert2rhel)

[github.com/oamg/convert2rhel](https://github.com/oamg/convert2rhel)

```bash
# All the variables for the deployment
subscription_name="development"
resource_group_name="rg-centos-to-rhel"
location="swedencentral"

vnet_name="vnet-vm"
subnet_vm_name="snet-vm"

vm_name="vm"
vm_username="azureuser"

if test -f ".env"; then
  # Password has been created so load it
  source .env
else
  # Generate password and store it
  vm_password=$(openssl rand -base64 32)
  echo "vm_password=$vm_password" > .env
fi

nsg_name="nsg-vm"
nsg_rule_ssh_name="ssh-rule"
nsg_rule_myip_name="myip-rule"

az account set --subscription $subscription_name -o table

# Create resource group
az group create -l $location -n $resource_group_name -o table

az network nsg create \
  --resource-group $resource_group_name \
  --name $nsg_name
  
my_ip=$(curl --no-progress-meter https://myip.jannemattila.com)
echo $my_ip

az network nsg rule create \
  --resource-group $resource_group_name \
  --nsg-name $nsg_name \
  --name $nsg_rule_ssh_name \
  --protocol '*' \
  --direction inbound \
  --source-address-prefix $my_ip \
  --source-port-range '*' \
  --destination-address-prefix '*' \
  --destination-port-range '22' \
  --access allow \
  --priority 100

vnet_id=$(az network vnet create -g $resource_group_name --name $vnet_name \
  --address-prefix 10.0.0.0/8 \
  --query newVNet.id -o tsv)
echo $vnet_id

subnet_vm_id=$(az network vnet subnet create -g $resource_group_name --vnet-name $vnet_name \
  --name $subnet_vm_name --address-prefixes 10.4.0.0/24 \
  --network-security-group $nsg_name \
  --query id -o tsv)
echo $subnet_vm_id

vm_json=$(az vm create \
  --resource-group $resource_group_name  \
  --name $vm_name \
  --image "OpenLogic:CentOs:7.5:latest" \
  --size Standard_DS1_v2 \
  --admin-username $vm_username \
  --admin-password $vm_password \
  --subnet $subnet_vm_id \
  --accelerated-networking true \
  --nsg "" \
  --public-ip-sku Standard \
  -o json)

vm_public_ip_address=$(echo $vm_json | jq -r .publicIpAddress)
echo $vm_public_ip_address

# Display variables
# Remember to enable auto export
set -a
echo vm_username=$vm_username
echo vm_password=$vm_password
echo vm_public_ip_address=$vm_public_ip_address

ssh $vm_username@$vm_public_ip_address

# Or using sshpass
sshpass -p $vm_password ssh $vm_username@$vm_public_ip_address
```

Inside VM:

```bash
# 1) Backup the VM

# 2) Update the VM
sudo yum –y update

# 3) Install Red Hat official keys and the convert2RHEL repo
sudo curl -o /etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release https://www.redhat.com/security/data/fd431d51.txt
sudo curl -o /etc/yum.repos.d/convert2rhel.repo https://ftp.redhat.com/redhat/convert2rhel/7/convert2rhel.repo

# 4) Install and configure convert2RHEL
sudo yum -y install convert2rhel
sudo cat /etc/convert2rhel.ini
sudo nano /etc/convert2rhel.ini

# 5) Convert the VM
sudo convert2rhel

# 6) Review and remove third party packages that don't have a RHEL component
yum list extras --disablerepo="*" --enablerepo=<RHEL_RepoID>

# ...
exit
```

```bash
#  7) Tell Azure this is a RHEL system
az vm extension set \
  --resource-group $resource_group_name \
  --vm-name $vm_name \
  --publisher Microsoft.Azure.AzureHybridBenefit \
  --name AHBForRHEL
```


```bash	
# Wipe out the resources
az group delete --name $resource_group_name -y

# Remove the password
rm .env
```

## Errors

```bash
[2024-06-12T10:34:12+0000] TASK - [Prepare: Gather system information] *******************************
CRITICAL - Couldn't parse the system release content string: CentOS Linux release 7.5.1804 (Core)
```