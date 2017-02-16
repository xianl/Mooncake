Login-AzureRmAccount -EnvironmentName AzureChinaCloud
# podnet@mcpod.partner.onmschina.cn

#Variables
$VMName = "FredDemo"
$RGName = "FredDemo"
$Region = "China East"
$SAName = "freddemostorage"
$VMSize = "Standard_A3"
$VNETName = "FredDemoVnet"
$Subnet01Name = "Subnet-1"
$Subnet02Name = "Subnet-2"
$PublicIPName = "freddemopublicIP"
$cred=Get-Credential -Message "Type the name and password of the local administrator account." 



# Getting the Network 

$VNET = Get-AzureRMvirtualNetwork | where {$_.Name -eq $VNETName} 
$SUBNET01 = Get-AzureRmVirtualNetworkSubnetConfig -Name $Subnet01Name -VirtualNetwork $VNET
$SUBNET02 = Get-AzureRmVirtualNetworkSubnetConfig -Name $Subnet02Name -VirtualNetwork $VNET


#create public IP

$PublicIP = New-AzureRmPublicIpAddress -Name $PublicIPName -AllocationMethod Static -ResourceGroupName $RGName -Location $Region


# Create the NICs
$NIC01Name = 'VNIC-'+$VMName+'-01'
$NIC02Name = 'VNIC-'+$VMName+'-02'
$VNIC01 = New-AzureRmNetworkInterface -Name $NIC01Name -ResourceGroupName $RGName -Location $Region -SubnetId $SUBNET01.Id -PublicIpAddressId $PublicIP.Id
$VNIC02 = New-AzureRmNetworkInterface -Name $NIC02Name -ResourceGroupName $RGName -Location $Region -SubnetId $SUBNET02.Id


# Create the VM config
$VM = New-AzureRmVMConfig -VMName $VMName -VMSize $VMSize 

$pubName="MicrosoftWindowsServer"
$offerName="WindowsServer"
$skuName="2012-R2-Datacenter-zhcn"
$VM = Set-AzureRmVMOperatingSystem -VM $vm -Windows -ComputerName $vmName -Credential $cred -ProvisionVMAgent -EnableAutoUpdate
$VM = Set-AzureRmVMSourceImage -VM $vm -PublisherName $pubName -Offer $offerName -Skus $skuName -Version "latest"
#Adding the VNICs to the config, you should always choose a Primary NIC
$VM = Add-AzureRmVMNetworkInterface -VM $VM -Id $VNIC01.Id -Primary
$VM = Add-AzureRmVMNetworkInterface -VM $VM -Id $VNIC02.Id


# Specify the OS disk name and create the VM
$DiskName='OSDisk-'+$VMName
$SA = Get-AzureRmStorageAccount | where { $_.StorageAccountName -eq $SAName}
$OSDiskUri = $SA.PrimaryEndpoints.Blob.ToString() + "vhds/" + $vmName+".vhd"
$VM = Set-AzureRmVMOSDisk -VM $VM -Name $DiskName -VhdUri $osDiskUri -CreateOption fromImage
New-AzureRmVM -ResourceGroupName $RGName -Location $Region -VM $VM