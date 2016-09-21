# Create a redundant haproxy setup with 2 Ubuntu VMs configured behind Azure load balancer with floating IP enabled.

<a href="https://portal.azure.cn/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fxianl%2Mooncake%2Fmaster%2Fhaproxy-redundant-floatingip-ubuntu%2Fazuredeploy.json" target="_blank">
    <img src="http://azuredeploy.net/deploybutton.png"/>
</a>
<a href="http://armviz.io/#/?load=https%3A%2F%2Fraw.githubusercontent.com%2Fxianl%2FMooncake%2Fmaster%2Fhaproxy-redundant-floatingip-ubuntu%2Fazuredeploy.json" target="_blank">
    <img src="http://armviz.io/visualizebutton.png"/>
</a>

This template creates 2 ubuntu (haproxy-lb) VMs under an *Azure load-balancer* (Azure-LB) configured with *floating IP* enabled. It also creates 2 additional Ubuntu (application) VMs running Apache (default configuration) for a proof-of-concept.

It uses *CustomScript Extension* to configure haproxy-lb VMs with haproxy/keepalived, and application VMs with apache2. The end-state configuration ensures only one of the haproxy-lb VMs is active and configured with the VIP (public IP) address.

It also deploys a Storage Account, Virtual Network, Public IP address, Availability Sets and Network Interfaces as required.

This template uses the resource loops capability to create network interfaces, virtual machines and extensions

### Notes
* Topology: Azure-LB -> haproxy-lb VMs (2) -> application VMs (2)
* Azure-LB
  * Azure-LB is configured with *enableFloatingIP* set to true in *loadBalancingRules*.
    * In this configuration, Azure-LB does not perform DNAT from public IP (VIP) to private IP address of the pool members. Instead, packets reach the pool member with the same destination IP set by the client.
  * Public IP **should** be configured on a network adapter of the pool member VMs to receive/respond to the requests.
* Haproxy-lb VMs
  * Public IP associated with Azure-LB is assigned to *only* one of the haproxy-lb VMs (MASTER as determined by keepalived).
  * Azure-LB probe on the other haproxy-lb VM (BACKUP) is explicitly disabled using a firewall(iptables) rule to block the LB probe port.
  * When a haproxy-lb VM status changes to MASTER, firewall rule(s) to block LB probe port is removed.
  * Custom keepalived verify and notify scripts are deployed to enable/disable probes as described above.
  * All configuration files are created as part of *CustomScript Extension*
* Application VMs
  * Apache webserver is deployed as part of *CustomScript Extension*. No changes are done to default configuration.
  * This is only a proof-of-concept. The functionality of application VMs can be modified per requirement. Corresponding changes need to be done to *variables* section of the template.
  * 
  

###Deploymennt Steps:

1.  First from the new portal, create a new resource group.
2.  From the Azure Powershell, run the command below to start the ARM deployment.

    New-AzureRmResourceGroupDeployment -Name [Deployment Name] -ResourceGroupName [Resource Group Name] -TemplateUri https://raw.githubusercontent.com/xianl/Mooncake/master/haproxy-redundant-floatingip-ubuntu/azuredeploy.json

3.  Wait until the deployment finished.
4.  SSH to the haproxy vm0 via the 50001 port and modify the /etc/keepalived/keepalived.conf to add the virtual IP address
    For example, the public Ip address assigned is 1.2.3.4, please modify the file as below. (this is because China Azure currently doesn't support *CustomScript Extension* version 2.0 , so we need to specify the virtual address manually)

    vrrp_script chk_appsvc {
            script /usr/local/sbin/keepalived-check-appsvc.sh
            interval 1
            fall 2
            rise 2
        }
        
        vrrp_instance VI_1 {
            interface eth0 
        
            authentication {
                auth_type PASS
                auth_pass secr3t
            }
        
            virtual_router_id 51
        
            virtual_ipaddress {
                1.2.3.4
            }
        
            track_script {
                chk_appsvc
            }
        
            notify /usr/local/sbin/keepalived-action.sh
            notify_stop "/usr/local/sbin/keepalived-action.sh INSTANCE VI_1 STOP"
        
        
            state MASTER
            priority 101
        
            unicast_src_ip 10.0.0.7
            unicast_peer {
                10.0.0.6
            }
        
        }

5.  restart the keepalived service 
    
    service keepalived stop
    
    service keepalived start

6.  SSH to the haproxy vm1 via the 50002 port and repeat step 4 & 5
