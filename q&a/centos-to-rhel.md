# CentOS to RHEL

[CentOS End-Of-Life guidance](https://learn.microsoft.com/en-us/azure/virtual-machines/workloads/centos/centos-end-of-life)

[How to convert CentOS Linux to Red Hat Enterprise Linux on Azure](https://techcommunity.microsoft.com/t5/linux-and-open-source-blog/how-to-convert-centos-linux-to-red-hat-enterprise-linux-on-azure/ba-p/3960735)

[Convert2RHEL: Move to Red Hat Enterprise Linux from other Linux distros](https://www.redhat.com/en/technologies/linux-platforms/enterprise-linux/migration-process/convert2rhel)

[github.com/oamg/convert2rhel](https://github.com/oamg/convert2rhel)

## Create CentOS VM to Azure

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
  --image "OpenLogic:CentOs:7_9-gen2:latest" \
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
## Inside VM

All below commands have been taken from here:

[How to convert CentOS Linux to Red Hat Enterprise Linux on Azure](https://techcommunity.microsoft.com/t5/linux-and-open-source-blog/how-to-convert-centos-linux-to-red-hat-enterprise-linux-on-azure/ba-p/3960735)

```bash
# 1) Backup the VM

# 2) Update the VM
sudo yum update -y

# 3) Install Red Hat official keys and the convert2RHEL repo
sudo curl -o /etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release https://www.redhat.com/security/data/fd431d51.txt
sudo curl -o /etc/yum.repos.d/convert2rhel.repo https://ftp.redhat.com/redhat/convert2rhel/7/convert2rhel.repo

# 3a) Set parameters:
# export CONVERT2RHEL_SKIP_KERNEL_CURRENCY_CHECK=1

# 4) Install and configure convert2RHEL
sudo yum -y install convert2rhel
sudo cat /etc/convert2rhel.ini
sudo nano /etc/convert2rhel.ini

# 5) Convert the VM
sudo convert2rhel --help
sudo convert2rhel --version
sudo convert2rhel

# 6) Review and remove third party packages that don't have a RHEL component
yum list extras --disablerepo="*" --enablerepo=<RHEL_RepoID>

# ...
exit
```

## After VM upgrade

```bash
#  7) Tell Azure this is a RHEL system
az vm extension set \
  --resource-group $resource_group_name \
  --vm-name $vm_name \
  --name AHBForRHEL \
  --publisher Microsoft.Azure.AzureHybridBenefit
# Or
az vm update \
  --resource-group $resource_group_name \
  --name $vm_name \
  --license-type RHEL_BYOS \
  --set tags.licensePrivateOfferId=$offer_id
```

## Test conversion 1

Starting point `7.5`:

```console
[azureuser@vm ~]$ uname -a
Linux vm 3.10.0-862.11.6.el7.x86_64 #1 SMP Tue Aug 14 21:49:04 UTC 2018 x86_64 x86_64 x86_64 GNU/Linux
[azureuser@vm ~]$ sudo yum install redhat-lsb-core
...a lot of output...
Complete!
[azureuser@vm ~]$ lsb_release -d
Description:    CentOS Linux release 7.5.1804 (Core) 
[azureuser@vm ~]$ hostnamectl
   Static hostname: vm
         Icon name: computer-vm
           Chassis: vm
        Machine ID: 97da09219a2d42489c8b8f748e6d2fb7
           Boot ID: f7c1d4a1a8f741548cf40662bfbe01ac
    Virtualization: microsoft
  Operating System: CentOS Linux 7 (Core)
       CPE OS Name: cpe:/o:centos:centos:7
            Kernel: Linux 3.10.0-862.11.6.el7.x86_64
      Architecture: x86-64
[azureuser@vm ~]$ cat /etc/os-release
NAME="CentOS Linux"
VERSION="7 (Core)"
ID="centos"
ID_LIKE="rhel fedora"
VERSION_ID="7"
PRETTY_NAME="CentOS Linux 7 (Core)"
ANSI_COLOR="0;31"
CPE_NAME="cpe:/o:centos:centos:7"
HOME_URL="https://www.centos.org/"
BUG_REPORT_URL="https://bugs.centos.org/"

CENTOS_MANTISBT_PROJECT="CentOS-7"
CENTOS_MANTISBT_PROJECT_VERSION="7"
REDHAT_SUPPORT_PRODUCT="centos"
REDHAT_SUPPORT_PRODUCT_VERSION="7"

[azureuser@vm ~]$
```

```bash
[2024-06-12T10:34:12+0000] TASK - [Prepare: Gather system information] *******************************
CRITICAL - Couldn't parse the system release content string: CentOS Linux release 7.5.1804 (Core)
```

Source [convert2rhel/convert2rhel/systeminfo.py#L208](https://github.com/oamg/convert2rhel/blob/2ed5019254029aaf72333fbf9ef06989061563f3/convert2rhel/systeminfo.py#L208).

Remember to run update before conversion:

```bash
sudo yum update -y
```

---

```bash
[2024-06-12T11:37:34+0000] TASK - [Prepare: Check if the loaded kernel version is the most recent] ***
ERROR - (OVERRIDABLE) IS_LOADED_KERNEL_LATEST::INVALID_KERNEL_VERSION - Invalid kernel version detected
 Description: The loaded kernel version mismatch the latest one available in system repositories
 Diagnosis: The version of the loaded kernel is different from the latest version in system repositories.
 Latest kernel version available in updates: 3.10.0-1160.119.1.el7
 Loaded kernel version: 3.10.0-862.11.6.el7
 Remediations: To proceed with the conversion, update the kernel version by executing the following step:

1. yum install kernel-3.10.0-1160.119.1.el7 -y
2. reboot
If you wish to ignore this message, set the environment variable 'CONVERT2RHEL_SKIP_KERNEL_CURRENCY_CHECK' to 1.
```

```bash
[2024-06-12T11:38:38+0000] TASK - [Prepare: Subscription Manager - Reload configuration] *************
ERROR - (ERROR) SUBSCRIBE_SYSTEM::SYSTEM_NOT_REGISTERED - Not registered with RHSM
 Description: This system must be registered with rhsm in order to get access to the RHEL rpms. In this case, the system was not already registered and no credentials were given to convert2rhel to register it.
 Diagnosis: N/A
 Remediations: You may either register this system via subscription-manager before running convert2rhel or give convert2rhel credentials to do that for you. The credentials convert2rhel would need are either activation_key and organization or username and password. You can set these in a config file and then pass the file to convert2rhel with the --config-file option.        

ERROR - Skipped ENSURE_KERNEL_MODULES_COMPATIBILITY. Skipped because SUBSCRIBE_SYSTEM was not successful
ERROR - Skipped VALIDATE_PACKAGE_MANAGER_TRANSACTION. Skipped because ENSURE_KERNEL_MODULES_COMPATIBILITY and SUBSCRIBE_SYSTEM were not successful
```

## Test conversion 2

Starting point `7.9`:

```console
[azureuser@vm ~]$ uname -a
Linux vm 3.10.0-1160.83.1.el7.x86_64 #1 SMP Wed Jan 25 16:41:43 UTC 2023 x86_64 x86_64 x86_64 GNU/Linux
[azureuser@vm ~]$ sudo yum install redhat-lsb-core
...a lot of output...
Complete!
[azureuser@vm ~]$ lsb_release -d
Description:    CentOS Linux release 7.9.2009 (Core)
[azureuser@vm ~]$ hostnamectl
   Static hostname: vm
         Icon name: computer-vm
           Chassis: vm
        Machine ID: 8ca0ae28c3004a6ebab3e150d6401647
           Boot ID: 544e714c7b1f45a4ba708775359e0455
    Virtualization: microsoft
  Operating System: CentOS Linux 7 (Core)
       CPE OS Name: cpe:/o:centos:centos:7
            Kernel: Linux 3.10.0-1160.83.1.el7.x86_64
      Architecture: x86-64
[azureuser@vm ~]$ cat /etc/os-release
NAME="CentOS Linux"
VERSION="7 (Core)"
ID="centos"
ID_LIKE="rhel fedora"
VERSION_ID="7"
PRETTY_NAME="CentOS Linux 7 (Core)"
ANSI_COLOR="0;31"
CPE_NAME="cpe:/o:centos:centos:7"
HOME_URL="https://www.centos.org/"
BUG_REPORT_URL="https://bugs.centos.org/"

CENTOS_MANTISBT_PROJECT="CentOS-7"
CENTOS_MANTISBT_PROJECT_VERSION="7"
REDHAT_SUPPORT_PRODUCT="centos"
REDHAT_SUPPORT_PRODUCT_VERSION="7"

[azureuser@vm ~]$
```

```console
[azureuser@vm ~]$ sudo convert2rhel
...a lot of output...
========== Info (No changes needed) ==========
(INFO) REMOVE_SPECIAL_PACKAGES::SPECIAL_PACKAGES_REMOVED - Special packages to be removed
     Description: We have identified installed packages that match a pre-defined list of packages that are to be removed during the conversion
     Diagnosis: The following packages will be removed during the conversion: geoipupdate-2.5.0-2.el7.x86_64, kmod-kvdo-6.1.3.23-5.el7.x86_64, libreport-plugin-
mantisbt-2.1.11-53.el7.centos.x86_64, centos-release-7-9.2009.2.el7.centos.x86_64
     Remediations: N/A

========== Warning (Review and fix if needed) ==========
(WARNING) LIST_THIRD_PARTY_PACKAGES::THIRD_PARTY_PACKAGE_DETECTED - Third party packages detected
     Description: Third party packages will not be replaced during the conversion.
     Diagnosis: Only packages signed by CentOS Linux are to be replaced. Red Hat support won't be provided for the following third party packages:
    WALinuxAgent-2.7.3.0-1_ol001.el7.noarch, azure-repo-svc-1.0-0.el7.centos.noarch
     Remediations: N/A
(WARNING) EFI::UEFI_BOOTLOADER_MISMATCH - UEFI bootloader mismatch
     Description: There was a UEFI bootloader mismatch.
     Diagnosis: The current UEFI bootloader '0001' is not referring to any binary UEFI file located on local EFI System Partition (ESP).
     Remediations: N/A

========== Skip (Could not be checked due to other failures) ==========
(SKIP) ENSURE_KERNEL_MODULES_COMPATIBILITY::SKIP - Skipped action
     Description: This action was skipped due to another action failing.
     Diagnosis: Skipped because SUBSCRIBE_SYSTEM was not successful
     Remediations: Please ensure that the SUBSCRIBE_SYSTEM check passes so that this Action can evaluate your system
(SKIP) VALIDATE_PACKAGE_MANAGER_TRANSACTION::SKIP - Skipped action
     Description: This action was skipped due to another action failing.
     Diagnosis: Skipped because ENSURE_KERNEL_MODULES_COMPATIBILITY and SUBSCRIBE_SYSTEM were not successful
     Remediations: Please ensure that the ENSURE_KERNEL_MODULES_COMPATIBILITY and SUBSCRIBE_SYSTEM check passes so that this Action can evaluate your system

========== Overridable (Review and either fix or ignore the failure) ==========
(OVERRIDABLE) IS_LOADED_KERNEL_LATEST::INVALID_KERNEL_VERSION - Invalid kernel version detected
     Description: The loaded kernel version mismatch the latest one available in system repositories
     Diagnosis: The version of the loaded kernel is different from the latest version in system repositories.
     Latest kernel version available in updates-openlogic: 3.10.0-1160.119.1.el7
     Loaded kernel version: 3.10.0-1160.83.1.el7
     Remediations: To proceed with the conversion, update the kernel version by executing the following step:

    1. yum install kernel-3.10.0-1160.119.1.el7 -y
    2. reboot
    If you wish to ignore this message, set the environment variable 'CONVERT2RHEL_SKIP_KERNEL_CURRENCY_CHECK' to 1.

========== Error (Must fix before conversion) ==========
(ERROR) SUBSCRIBE_SYSTEM::SYSTEM_NOT_REGISTERED - Not registered with RHSM
     Description: This system must be registered with rhsm in order to get access to the RHEL rpms. In this case, the system was not already registered and no credentials were given to     
convert2rhel to register it.
     Diagnosis: N/A
     Remediations: You may either register this system via subscription-manager before running convert2rhel or give convert2rhel credentials to do that for you. The credentials convert2rhel
would need are either activation_key and organization or username and password. You can set these in a config file and then pass the file to convert2rhel with the --config-file option.     

[azureuser@vm ~]$
```

## Cleanup

```bash	
# Wipe out the resources
az group delete --name $resource_group_name -y

# Remove the password
rm .env
```