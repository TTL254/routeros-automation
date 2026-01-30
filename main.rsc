# Modular MikroTik RouterOS configuration script for CCR2004-1G-12S+2XS

# ====================== What this script configures: ======================
# 1. Sets the router hostname and timezone.
# 2. Configures NTP client for time synchronization with NTP servers.
# 3. Configures DNS servers for name resolution.
# 4. Creates a bridge for VLAN trunking with VLAN filtering enabled.
# 5. Adds all trunk ports (SFP+ and XS) to the bridge in trunk mode.
# 6. Creates VLAN interfaces on the bridge and assigns IP addresses to each VLAN.
# 7. Assigns an IP address to the management interface (ether1).
# 8. Creates interface list "LAN-VLANS" containing all VLAN interfaces (for convenient reference in firewall rules).
# 9. Enables the DNS server on the router and allows remote requests.
# 10. Configures basic firewall:
#     - Allows management access only from the management interface
#     - Logs unauthorized access attempts
#     - Allows DNS queries from VLAN interfaces
#     - Enables inter-VLAN routing
# 11. Disables unnecessary services (telnet, ftp, etc.) for security hardening.
# 12. Configures logging:
#     - Forwards selected topics to a remote syslog server
#     - Enables local logging for firewall actions
# 13. Configures SNMP:
#     - Enables SNMP service
#     - Sets SNMP community string
#     - Configures SNMP traps destination
# =====================================================================

# ====================== Configuration Variables ======================
:local hostname "CoreRouter"
:local timezone "Europe/Kiev"
:local ntpServers {"0.pool.ntp.org"; "1.pool.ntp.org"}
:local dnsServers "8.8.8.8,8.8.4.4"
:local managementInterface "ether1"
:local managementIp "192.168.88.1/24"
:local bridgeName "bridge-vlan"

# Trunk ports
:local trunkPorts {
  "sfp-sfpplus1"; "sfp-sfpplus2"; "sfp-sfpplus3"; "sfp-sfpplus4";
  "sfp-sfpplus5"; "sfp-sfpplus6"; "sfp-sfpplus7"; "sfp-sfpplus8";
  "sfp-sfpplus9"; "sfp-sfpplus10"; "sfp-sfpplus11"; "sfp-sfpplus12";
  "sfp28-1"; "sfp28-2"
}

# VLANs
:local vlans {
  {vlanId=10; vlanName="vlan10"; ipAddress="10.0.10.1/24"};
  {vlanId=20; vlanName="vlan20"; ipAddress="10.0.20.1/24"};
  {vlanId=30; vlanName="vlan30"; ipAddress="10.0.30.1/24"}
}

# New: DNS Server settings
:local enableDnsServer yes
:local dnsServerPort 53

# SNMP
:local snmpEnabled yes
:local snmpCommunity "public"
:local snmpContact "admin@example.com"
:local snmpLocation "Data Center"
:local snmpTrapTarget "192.168.100.100"

# Logging
:local loggingServer "192.168.100.101:514"

# =====================================================================

# Basic settings
/system identity set name=$hostname
/system clock set time-zone-name=$timezone

# NTP
/system ntp client set enabled=yes
:foreach s in=$ntpServers do={ /system ntp client servers add address=$s }

/ip dns set servers=$dnsServers

# Bridge + Trunk ports
/interface bridge add name=$bridgeName vlan-filtering=yes

:foreach port in=$trunkPorts do={
  /interface bridge port add bridge=$bridgeName interface=$port pvid=1 ingress-filtering=yes frame-types=admit-all
}

# VLAN interfaces + IP addresses
:foreach v in=$vlans do={
  :local id ($v->"vlanId")
  :local name ($v->"vlanName")
  :local ip ($v->"ipAddress")
  
  /interface vlan add interface=$bridgeName name=$name vlan-id=$id
  /ip address add address=$ip interface=$name
}

# Management IP
/ip address add address=$managementIp interface=$managementInterface

# Interface list for all VLANs (для зручного firewall)
 /interface list add name=LAN-VLANS
:foreach v in=$vlans do={
  /interface list member add list=LAN-VLANS interface=($v->"vlanName")
}

# DNS Server activation
:if ($enableDnsServer) do={
  /ip dns set allow-remote-requests=yes cache-size=8192
}

# ====================== Firewall ======================
/ip firewall filter

add chain=input action=accept connection-state=established,related comment="Allow established/related"
add chain=input action=accept in-interface=$managementInterface comment="Allow management access"

# === DNS access from VLANs ===
:if ($enableDnsServer) do={
  add chain=input action=accept protocol=udp dst-port=$dnsServerPort in-interface-list=LAN-VLANS comment="Allow DNS UDP from VLANs"
  add chain=input action=accept protocol=tcp dst-port=$dnsServerPort in-interface-list=LAN-VLANS comment="Allow DNS TCP from VLANs"
}

add chain=input action=log log=yes log-prefix="UNAUTH-ACCESS" place-before=0 comment="Log unauthorized access"
add chain=input action=drop comment="Drop all other input"

add chain=forward action=accept connection-state=established,related
add chain=forward action=drop connection-state=invalid
add chain=forward action=accept comment="Allow inter-VLAN routing"

# Disable dangerous services
/ip service set telnet disabled=yes
/ip service set ftp disabled=yes
/ip service set www disabled=yes
/ip service set api disabled=yes
/ip service set api-ssl disabled=yes

# ====================== Logging & SNMP ======================
/system logging action add name=remote target=remote remote=$loggingServer
/system logging add topics=firewall action=remote
/system logging add topics=firewall action=memory

# SNMP (optional)
:if ($snmpEnabled) do={
  /system snmp set enabled=yes contact=$snmpContact location=$snmpLocation
  /system snmp community add name=$snmpCommunity
  /snmp target add address=$snmpTrapTarget version=2c community=$snmpCommunity
}

# End of script