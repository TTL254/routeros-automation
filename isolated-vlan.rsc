# Isolated VLAN 254 settings
:local isolatedVlanId 254
:local isolatedVlanName "vlan254"
:local isolatedIp "192.168.254.1/24"
:local isolatedSubnet "192.168.254.0/24"

# З яких мереж дозволено доступ до VM у VLAN 254
:local allowedToIsolated {"192.168.88.0/24"}   ; # management subnet

# ====================== Firewall ======================
/ip firewall filter

add chain=input action=accept connection-state=established,related comment="Allow established/related"
add chain=input action=accept in-interface=$managementInterface comment="Allow management access"

# DNS доступ з звичайних VLAN (не з isolated)
:if ($enableDnsServer) do={
  add chain=input action=accept protocol=udp dst-port=$dnsServerPort in-interface-list=LAN-VLANS comment="Allow DNS UDP from normal VLANs"
  add chain=input action=accept protocol=tcp dst-port=$dnsServerPort in-interface-list=LAN-VLANS comment="Allow DNS TCP from normal VLANs"
}

# === Isolated VLAN 254 rules ===
add chain=input action=log log=yes log-prefix="ISOLATED-ACCESS-ATTEMPT" src-address=$isolatedSubnet in-interface=$isolatedVlanName comment="LOG all access attempts from Isolated VLAN"
add chain=input action=drop src-address=$isolatedSubnet in-interface=$isolatedVlanName comment="DROP all access to router from Isolated VLAN"

# Forward chain
add chain=forward action=accept connection-state=established,related comment="Allow established/related"

# Дозволити доступ до VM тільки з дозволених мереж
:foreach net in=$allowedToIsolated do={
  add chain=forward action=accept dst-address=$isolatedSubnet src-address=$net comment="Allow access to Isolated VMs from $net"
}

# Заборонити вихідний трафік від VM (ініціація з'єднань)
add chain=forward action=log log=yes log-prefix="ISOLATED-OUT-ATTEMPT" src-address=$isolatedSubnet comment="LOG outgoing attempts from Isolated VLAN"
add chain=forward action=drop src-address=$isolatedSubnet comment="DROP all outgoing from Isolated VLAN"

# Заборонити невалідні пакети
add chain=forward action=drop connection-state=invalid

# Дозволити inter-VLAN routing між звичайними VLAN
add chain=forward action=accept comment="Allow inter-VLAN routing between normal VLANs"

# Drop все інше
add chain=forward action=drop comment="Drop all other forward traffic"