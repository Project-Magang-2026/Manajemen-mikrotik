import 'package:flutter/material.dart';

class WinboxCategory {
  final String title;
  final IconData icon;
  final List<WinboxSubMenu> subMenus;

  const WinboxCategory(this.title, this.icon, this.subMenus);
}

class WinboxSubMenu {
  final String title;
  final String path;
  final String primaryField;
  final String? secondaryField;
  final List<String> displayColumns;

  const WinboxSubMenu(
    this.title,
    this.path,
    this.primaryField,
    this.secondaryField, [
    this.displayColumns = const [],
  ]);
}

class WinboxMenuItemReference {
  final int categoryIndex;
  final int subMenuIndex;
  final WinboxCategory category;
  final WinboxSubMenu subMenu;

  const WinboxMenuItemReference({
    required this.categoryIndex,
    required this.subMenuIndex,
    required this.category,
    required this.subMenu,
  });
}

class QuickMenuGroup {
  final String title;
  final IconData icon;
  final Color color;
  final List<String> paths;

  const QuickMenuGroup({
    required this.title,
    required this.icon,
    required this.color,
    required this.paths,
  });
}

const List<QuickMenuGroup> quickMenuGroups = [
  QuickMenuGroup(
    title: 'IP & Jaringan',
    icon: Icons.language_rounded,
    color: Color(0xFF007AFF),
    paths: [
      '/ip/address',
      '/ip/route',
      '/ip/dhcp-server/lease',
      '/ip/dhcp-server',
      '/ip/arp',
      '/ip/dns',
      '/ip/pool',
    ],
  ),
  QuickMenuGroup(
    title: 'Firewall & Keamanan',
    icon: Icons.security_rounded,
    color: Color(0xFFFF9500),
    paths: [
      '/ip/firewall/nat',
      '/ip/firewall/filter',
      '/ip/firewall/mangle',
      '/ip/firewall/address-list',
    ],
  ),
  QuickMenuGroup(
    title: 'Queues & Bandwidth',
    icon: Icons.speed_rounded,
    color: Color(0xFF34C759),
    paths: [
      '/queue/simple',
      '/queue/tree',
    ],
  ),
  QuickMenuGroup(
    title: 'Interfaces & VLAN',
    icon: Icons.lan_rounded,
    color: Color(0xFF5856D6),
    paths: [
      '/interface',
      '/interface/ethernet',
      '/interface/bridge',
      '/interface/vlan',
      '/interface/wireguard',
    ],
  ),
  QuickMenuGroup(
    title: 'PPP & PPPoE',
    icon: Icons.people_outline_rounded,
    color: Color(0xFFAF52DE),
    paths: [
      '/ppp/secret',
      '/ppp/active',
      '/ppp/profile',
      '/interface/pppoe-server/server',
    ],
  ),
  QuickMenuGroup(
    title: 'Log & Diagnostik',
    icon: Icons.terminal_rounded,
    color: Color(0xFFFF2D55),
    paths: [
      '/log',
      'CLI_TOOL',
      'PING_TOOL',
      'PROFILE_TOOL',
    ],
  ),
  QuickMenuGroup(
    title: 'Sistem Router',
    icon: Icons.dns_rounded,
    color: Color(0xFF6C6C70),
    paths: [
      '/system/resource',
      '/system/routerboard',
      '/user',
      'SYSTEM_REBOOT',
    ],
  ),
];

WinboxMenuItemReference? findWinboxMenuByPath(String path) {
  for (int c = 0; c < winboxCategories.length; c++) {
    for (int s = 0; s < winboxCategories[c].subMenus.length; s++) {
      if (winboxCategories[c].subMenus[s].path == path) {
        return WinboxMenuItemReference(
          categoryIndex: c,
          subMenuIndex: s,
          category: winboxCategories[c],
          subMenu: winboxCategories[c].subMenus[s],
        );
      }
    }
  }
  return null;
}

List<WinboxMenuItemReference> searchWinboxMenus(String query) {
  final q = query.trim().toLowerCase();
  final results = <WinboxMenuItemReference>[];
  for (int c = 0; c < winboxCategories.length; c++) {
    final cat = winboxCategories[c];
    for (int s = 0; s < cat.subMenus.length; s++) {
      final sub = cat.subMenus[s];
      if (q.isEmpty ||
          cat.title.toLowerCase().contains(q) ||
          sub.title.toLowerCase().contains(q) ||
          sub.path.toLowerCase().contains(q)) {
        results.add(WinboxMenuItemReference(
          categoryIndex: c,
          subMenuIndex: s,
          category: cat,
          subMenu: sub,
        ));
      }
    }
  }
  return results;
}

const List<WinboxCategory> winboxCategories = [
  WinboxCategory('Quick Set', Icons.speed_rounded, [
    WinboxSubMenu('System Resource', '/system/resource', 'board-name', 'version', ['board-name', 'version', 'cpu-load', 'uptime', 'free-memory']),
    WinboxSubMenu('RouterBOARD', '/system/routerboard', 'model', 'current-firmware', ['model', 'serial-number', 'current-firmware', 'upgrade-firmware']),
    WinboxSubMenu('Health Sensors', '/system/health', 'name', 'value', ['name', 'value', 'type']),
  ]),
  WinboxCategory('Interfaces', Icons.lan_rounded, [
    WinboxSubMenu('Interface List', '/interface', 'name', 'type', ['name', 'type', 'actual-mtu', 'mac-address', 'rx-byte', 'tx-byte']),
    WinboxSubMenu('Ethernet', '/interface/ethernet', 'name', 'mac-address', ['name', 'mac-address', 'speed', 'full-duplex']),
    WinboxSubMenu('VLAN', '/interface/vlan', 'name', 'vlan-id', ['name', 'vlan-id', 'interface', 'mtu']),
    WinboxSubMenu('Bridge', '/interface/bridge', 'name', 'mac-address', ['name', 'mac-address', 'mtu', 'fast-forward']),
    WinboxSubMenu('Bridge Ports', '/interface/bridge/port', 'interface', 'bridge', ['interface', 'bridge', 'priority', 'path-cost']),
    WinboxSubMenu('Bridge VLANs', '/interface/bridge/vlan', 'bridge', 'vlan-ids', ['bridge', 'vlan-ids', 'tagged', 'untagged']),
    WinboxSubMenu('Bridge Hosts', '/interface/bridge/host', 'mac-address', 'bridge', ['mac-address', 'bridge', 'on-interface', 'age']),
    WinboxSubMenu('Bridge Filter', '/interface/bridge/filter', 'chain', 'action', ['chain', 'action', 'in-interface', 'out-interface', 'mac-protocol']),
    WinboxSubMenu('Bridge NAT', '/interface/bridge/nat', 'chain', 'action', ['chain', 'action', 'to-dst-mac-address']),
    WinboxSubMenu('Bonding', '/interface/bonding', 'name', 'mode', ['name', 'slaves', 'mode']),
    WinboxSubMenu('WireGuard', '/interface/wireguard', 'name', 'listen-port', ['name', 'listen-port', 'public-key']),
    WinboxSubMenu('WireGuard Peers', '/interface/wireguard/peers', 'interface', 'public-key', ['interface', 'public-key', 'allowed-address', 'endpoint-address']),
    WinboxSubMenu('VRRP', '/interface/vrrp', 'name', 'vrid', ['name', 'interface', 'vrid', 'priority']),
    WinboxSubMenu('EoIP Tunnel', '/interface/eoip', 'name', 'remote-address', ['name', 'remote-address', 'tunnel-id']),
    WinboxSubMenu('GRE Tunnel', '/interface/gre', 'name', 'remote-address', ['name', 'remote-address', 'dscp']),
    WinboxSubMenu('IPIP Tunnel', '/interface/ipip', 'name', 'remote-address', ['name', 'remote-address', 'dscp']),
    WinboxSubMenu('LTE', '/interface/lte', 'name', 'pin', ['name', 'pin', 'network-mode']),
    WinboxSubMenu('PPPoE Client', '/interface/pppoe-client', 'name', 'user', ['name', 'interface', 'user', 'service-name']),
  ]),
  WinboxCategory('Wireless', Icons.wifi_rounded, [
    WinboxSubMenu('WiFi Interfaces', '/interface/wireless', 'name', 'ssid', ['name', 'ssid', 'band', 'frequency', 'mode']),
    WinboxSubMenu('Registration Table', '/interface/wireless/registration-table', 'mac-address', 'signal-strength', ['mac-address', 'interface', 'signal-strength', 'tx-rate', 'rx-rate', 'uptime']),
    WinboxSubMenu('Security Profiles', '/interface/wireless/security-profiles', 'name', 'mode', ['name', 'mode', 'authentication-types']),
    WinboxSubMenu('Access List', '/interface/wireless/access-list', 'mac-address', 'interface', ['mac-address', 'interface', 'signal-range', 'authentication']),
    WinboxSubMenu('Connect List', '/interface/wireless/connect-list', 'interface', 'mac-address', ['interface', 'mac-address', 'connect']),
    WinboxSubMenu('Channels', '/interface/wireless/channels', 'name', 'frequency', ['name', 'frequency', 'width', 'band']),
    WinboxSubMenu('CAPsMAN', '/caps-man/interface', 'name', 'radio-mac', ['name', 'radio-mac', 'configuration']),
  ]),
  WinboxCategory('Bridge', Icons.alt_route_rounded, [
    WinboxSubMenu('Bridges', '/interface/bridge', 'name', 'mac-address', ['name', 'mac-address', 'mtu']),
    WinboxSubMenu('Ports', '/interface/bridge/port', 'interface', 'bridge', ['interface', 'bridge', 'priority', 'path-cost']),
    WinboxSubMenu('VLANs', '/interface/bridge/vlan', 'bridge', 'vlan-ids', ['bridge', 'vlan-ids', 'tagged', 'untagged']),
    WinboxSubMenu('Hosts', '/interface/bridge/host', 'mac-address', 'bridge', ['mac-address', 'bridge', 'on-interface', 'age']),
    WinboxSubMenu('Filter Rules', '/interface/bridge/filter', 'chain', 'action', ['chain', 'action', 'in-interface', 'out-interface']),
    WinboxSubMenu('NAT Rules', '/interface/bridge/nat', 'chain', 'action', ['chain', 'action', 'to-dst-mac-address']),
  ]),
  WinboxCategory('PPP', Icons.people_outline_rounded, [
    WinboxSubMenu('Secrets', '/ppp/secret', 'name', 'profile', ['name', 'service', 'profile', 'local-address', 'remote-address']),
    WinboxSubMenu('Active Connections', '/ppp/active', 'name', 'address', ['name', 'service', 'caller-id', 'address', 'uptime']),
    WinboxSubMenu('Profiles', '/ppp/profile', 'name', 'local-address', ['name', 'local-address', 'remote-address', 'rate-limit', 'dns-server']),
    WinboxSubMenu('PPPoE Servers', '/interface/pppoe-server/server', 'service-name', 'interface', ['service-name', 'interface', 'max-mtu', 'default-profile']),
    WinboxSubMenu('PPPoE Clients', '/interface/pppoe-client', 'name', 'user', ['name', 'interface', 'user', 'service-name']),
    WinboxSubMenu('L2TP Server', '/interface/l2tp-server/server', 'enabled', 'default-profile', ['enabled', 'default-profile', 'max-mtu']),
    WinboxSubMenu('SSTP Server', '/interface/sstp-server/server', 'enabled', 'port', ['enabled', 'port', 'default-profile', 'certificate']),
    WinboxSubMenu('OVPN Server', '/interface/ovpn-server/server', 'enabled', 'port', ['enabled', 'port', 'mode', 'default-profile', 'certificate']),
  ]),
  WinboxCategory('Switch & Mesh', Icons.hub_rounded, [
    WinboxSubMenu('Switch Settings', '/interface/ethernet/switch', 'name', 'type', ['name', 'type', 'cpu']),
    WinboxSubMenu('Switch Ports', '/interface/ethernet/switch/port', 'name', 'switch', ['name', 'switch', 'vlan-mode', 'default-vlan-id']),
    WinboxSubMenu('Switch VLANs', '/interface/ethernet/switch/vlan', 'switch', 'vlan-id', ['switch', 'vlan-id', 'ports']),
    WinboxSubMenu('Switch Hosts', '/interface/ethernet/switch/host', 'mac-address', 'port', ['mac-address', 'port', 'vlan-id']),
    WinboxSubMenu('Switch Rules', '/interface/ethernet/switch/rule', 'switch', 'ports', ['switch', 'ports', 'mac-protocol', 'new-vlan-id']),
    WinboxSubMenu('Mesh Interfaces', '/interface/mesh', 'name', 'mac-address', ['name', 'mac-address', 'mtu']),
    WinboxSubMenu('Mesh Ports', '/interface/mesh/port', 'interface', 'mesh', ['interface', 'mesh']),
  ]),
  WinboxCategory('IP', Icons.language_rounded, [
    WinboxSubMenu('Addresses', '/ip/address', 'address', 'interface', ['address', 'network', 'interface', 'actual-interface']),
    WinboxSubMenu('ARP Table', '/ip/arp', 'address', 'mac-address', ['address', 'mac-address', 'interface']),
    WinboxSubMenu('Routes', '/ip/route', 'dst-address', 'gateway', ['dst-address', 'gateway', 'distance', 'scope', 'pref-src']),
    WinboxSubMenu('Nexthops', '/ip/route/nexthop', 'address', 'interface', ['address', 'interface', 'metric']),
    WinboxSubMenu('VRF', '/ip/route/vrf', 'name', 'interfaces', ['name', 'interfaces', 'route-distinguisher']),
    WinboxSubMenu('DHCP Client', '/ip/dhcp-client', 'interface', 'status', ['interface', 'use-peer-dns', 'status', 'address']),
    WinboxSubMenu('DHCP Server', '/ip/dhcp-server', 'name', 'interface', ['name', 'interface', 'lease-time', 'address-pool']),
    WinboxSubMenu('DHCP Leases', '/ip/dhcp-server/lease', 'address', 'host-name', ['address', 'mac-address', 'host-name', 'server', 'status', 'expires-after']),
    WinboxSubMenu('DHCP Networks', '/ip/dhcp-server/network', 'address', 'gateway', ['address', 'gateway', 'dns-server', 'domain']),
    WinboxSubMenu('DHCP Options', '/ip/dhcp-server/option', 'name', 'code', ['name', 'code', 'value']),
    WinboxSubMenu('DHCP Relay', '/ip/dhcp-relay', 'name', 'interface', ['name', 'interface', 'dhcp-server']),
    WinboxSubMenu('DNS Settings', '/ip/dns', 'servers', 'dynamic-servers', ['servers', 'dynamic-servers', 'allow-remote-requests']),
    WinboxSubMenu('DNS Static', '/ip/dns/static', 'name', 'address', ['name', 'address', 'ttl']),
    WinboxSubMenu('DNS Cache', '/ip/dns/cache', 'name', 'data', ['name', 'type', 'data', 'ttl']),
    WinboxSubMenu('IP Pool', '/ip/pool', 'name', 'ranges', ['name', 'ranges', 'next-pool']),
    WinboxSubMenu('Services', '/ip/service', 'name', 'port', ['name', 'port', 'address', 'certificate']),
    WinboxSubMenu('Cloud DDNS', '/ip/cloud', 'dns-name', 'status', ['dns-name', 'public-address', 'status', 'update-time']),
    WinboxSubMenu('Hotspot Servers', '/ip/hotspot', 'name', 'interface', ['name', 'interface', 'address-pool', 'profile']),
    WinboxSubMenu('Hotspot Users', '/ip/hotspot/user', 'name', 'profile', ['name', 'password', 'profile', 'uptime', 'bytes-in', 'bytes-out']),
    WinboxSubMenu('Hotspot Active', '/ip/hotspot/active', 'user', 'address', ['user', 'address', 'mac-address', 'uptime', 'session-time-left']),
    WinboxSubMenu('Hotspot Hosts', '/ip/hotspot/host', 'mac-address', 'address', ['mac-address', 'address', 'to-address', 'server', 'bridge-port']),
    WinboxSubMenu('Hotspot IP Binding', '/ip/hotspot/ip-binding', 'mac-address', 'type', ['mac-address', 'address', 'to-address', 'type']),
    WinboxSubMenu('Hotspot User Profiles', '/ip/hotspot/user/profile', 'name', 'shared-users', ['name', 'shared-users', 'rate-limit', 'transparent-proxy']),
    WinboxSubMenu('Hotspot Server Profiles', '/ip/hotspot/profile', 'name', 'hotspot-address', ['name', 'hotspot-address', 'dns-name', 'html-directory']),
    WinboxSubMenu('Hotspot Cookies', '/ip/hotspot/cookie', 'user', 'mac-address', ['user', 'mac-address', 'expires-in']),
    WinboxSubMenu('Web Proxy', '/ip/proxy', 'enabled', 'port', ['enabled', 'port', 'cache-administrator']),
    WinboxSubMenu('UPnP', '/ip/upnp', 'enabled', 'allow-disable-external-interface', ['enabled', 'allow-disable-external-interface']),
    WinboxSubMenu('TFTP', '/ip/tftp', 'req-filename', 'real-filename', ['req-filename', 'real-filename', 'allow']),
    WinboxSubMenu('Socks', '/ip/socks', 'enabled', 'port', ['enabled', 'port', 'connection-idle-timeout']),
    WinboxSubMenu('SMB', '/ip/smb', 'enabled', 'domain', ['enabled', 'domain', 'comment']),
    WinboxSubMenu('SNMP', '/snmp', 'enabled', 'contact', ['enabled', 'contact', 'location']),
    WinboxSubMenu('Traffic Flow', '/ip/traffic-flow', 'enabled', 'interfaces', ['enabled', 'interfaces', 'cache-entries']),
    WinboxSubMenu('Accounting', '/ip/accounting', 'enabled', 'account-local-traffic', ['enabled', 'account-local-traffic', 'threshold']),
    WinboxSubMenu('Kid Control', '/ip/kid-control', 'enabled', null, ['enabled']),
    WinboxSubMenu('Kid Control Devices', '/ip/kid-control/device', 'name', 'mac-address', ['name', 'mac-address', 'user', 'activity']),
  ]),
  WinboxCategory('IPv6', Icons.public_rounded, [
    WinboxSubMenu('Addresses', '/ipv6/address', 'address', 'interface', ['address', 'from-pool', 'interface', 'actual-interface']),
    WinboxSubMenu('Routes', '/ipv6/route', 'dst-address', 'gateway', ['dst-address', 'gateway', 'distance', 'metric']),
    WinboxSubMenu('Neighbors', '/ipv6/neighbor', 'address', 'mac-address', ['address', 'mac-address', 'interface', 'status']),
    WinboxSubMenu('DHCP Client', '/ipv6/dhcp-client', 'interface', 'pool-name', ['interface', 'status', 'pool-name', 'prefix']),
    WinboxSubMenu('DHCP Server', '/ipv6/dhcp-server', 'name', 'interface', ['name', 'interface', 'address-pool']),
    WinboxSubMenu('IP Pools', '/ipv6/pool', 'name', 'prefix', ['name', 'prefix', 'prefix-length']),
    WinboxSubMenu('ND (Neighbor Disc.)', '/ipv6/nd', 'interface', 'ra-interval', ['interface', 'ra-interval', 'ra-lifetime']),
    WinboxSubMenu('Firewall Filter', '/ipv6/firewall/filter', 'chain', 'action', ['chain', 'action', 'src-address', 'dst-address']),
  ]),
  WinboxCategory('Firewall', Icons.security_rounded, [
    WinboxSubMenu('Filter Rules', '/ip/firewall/filter', 'chain', 'action', ['chain', 'action', 'src-address', 'dst-address', 'protocol', 'dst-port', 'comment']),
    WinboxSubMenu('NAT Rules', '/ip/firewall/nat', 'chain', 'action', ['chain', 'action', 'to-addresses', 'to-ports', 'out-interface', 'comment']),
    WinboxSubMenu('Mangle Rules', '/ip/firewall/mangle', 'chain', 'action', ['chain', 'action', 'new-packet-mark', 'new-connection-mark', 'passthrough']),
    WinboxSubMenu('Raw Rules', '/ip/firewall/raw', 'chain', 'action', ['chain', 'action', 'src-address', 'dst-address']),
    WinboxSubMenu('Address Lists', '/ip/firewall/address-list', 'list', 'address', ['list', 'address', 'timeout', 'comment']),
    WinboxSubMenu('Connections', '/ip/firewall/connection', 'src-address', 'dst-address', ['protocol', 'src-address', 'dst-address', 'reply-src-address', 'tcp-state']),
    WinboxSubMenu('Service Ports', '/ip/firewall/service-port', 'name', 'ports', ['name', 'ports']),
    WinboxSubMenu('Layer7 Protocols', '/ip/firewall/layer7-protocol', 'name', 'regexp', ['name', 'regexp']),
  ]),
  WinboxCategory('Routing', Icons.directions_rounded, [
    WinboxSubMenu('BGP Connections', '/routing/bgp/connection', 'name', 'remote.address', ['name', 'remote.address', 'remote.as', 'local.role']),
    WinboxSubMenu('BGP Sessions', '/routing/bgp/session', 'name', 'remote.address', ['name', 'remote.address', 'state', 'uptime']),
    WinboxSubMenu('BGP Templates', '/routing/bgp/template', 'name', 'as', ['name', 'as', 'routing-table']),
    WinboxSubMenu('OSPF Instances', '/routing/ospf/instance', 'name', 'router-id', ['name', 'router-id', 'version']),
    WinboxSubMenu('OSPF Areas', '/routing/ospf/area', 'name', 'instance', ['name', 'instance', 'area-id']),
    WinboxSubMenu('OSPF Interfaces', '/routing/ospf/interface-template', 'area', 'interfaces', ['area', 'interfaces', 'cost', 'priority']),
    WinboxSubMenu('RIP Instances', '/routing/rip/instance', 'name', 'version', ['name', 'version']),
    WinboxSubMenu('Routing Filters', '/routing/filter/rule', 'chain', 'rule', ['chain', 'rule']),
    WinboxSubMenu('Routing Tables', '/routing/table', 'name', 'fib', ['name', 'fib']),
  ]),
  WinboxCategory('Queues', Icons.network_check_rounded, [
    WinboxSubMenu('Simple Queues', '/queue/simple', 'name', 'max-limit', ['name', 'target', 'max-limit', 'bytes', 'total-bytes', 'comment']),
    WinboxSubMenu('Queue Tree', '/queue/tree', 'name', 'parent', ['name', 'parent', 'packet-mark', 'max-limit', 'priority']),
    WinboxSubMenu('Queue Types', '/queue/type', 'name', 'kind', ['name', 'kind']),
    WinboxSubMenu('Interface Queues', '/queue/interface', 'interface', 'queue', ['interface', 'queue']),
  ]),
  WinboxCategory('Files', Icons.folder_rounded, [
    WinboxSubMenu('File Manager', '/file', 'name', 'size', ['name', 'type', 'size', 'creation-time']),
  ]),
  WinboxCategory('Log', Icons.receipt_long_rounded, [
    WinboxSubMenu('System Logs', '/log', 'time', 'message', ['time', 'topics', 'message']),
    WinboxSubMenu('Logging Rules', '/system/logging', 'topics', 'action', ['topics', 'action', 'prefix']),
    WinboxSubMenu('Logging Actions', '/system/logging/action', 'name', 'target', ['name', 'target', 'remember']),
  ]),
  WinboxCategory('Radius', Icons.radio_button_checked_rounded, [
    WinboxSubMenu('Radius Servers', '/radius', 'service', 'address', ['service', 'address', 'secret', 'authentication-port', 'accounting-port']),
    WinboxSubMenu('Incoming', '/radius/incoming', 'port', null, ['accept', 'port']),
  ]),
  WinboxCategory('System', Icons.dns_rounded, [
    WinboxSubMenu('Resources', '/system/resource', 'board-name', 'version', ['board-name', 'version', 'cpu-load', 'free-memory', 'total-memory', 'uptime']),
    WinboxSubMenu('RouterBOARD', '/system/routerboard', 'model', 'current-firmware', ['routerboard', 'model', 'serial-number', 'current-firmware', 'upgrade-firmware']),
    WinboxSubMenu('Health Sensors', '/system/health', 'name', 'value', ['name', 'value', 'type']),
    WinboxSubMenu('RouterOS Users', '/user', 'name', 'group', ['name', 'group', 'last-logged-in']),
    WinboxSubMenu('User Groups', '/user/group', 'name', 'policy', ['name', 'policy']),
    WinboxSubMenu('Active Users', '/user/active', 'name', 'via', ['name', 'when', 'via', 'address']),
    WinboxSubMenu('Packages', '/system/package', 'name', 'version', ['name', 'version', 'build-time']),
    WinboxSubMenu('Clock', '/system/clock', 'time', 'date', ['time', 'date', 'time-zone-name']),
    WinboxSubMenu('NTP Client', '/system/ntp/client', 'server-dns-names', 'status', ['enabled', 'mode', 'server-dns-names', 'status']),
    WinboxSubMenu('Scripts', '/system/script', 'name', 'last-started', ['name', 'owner', 'last-started', 'run-count']),
    WinboxSubMenu('Scheduler', '/system/scheduler', 'name', 'interval', ['name', 'start-date', 'start-time', 'interval', 'next-run']),
    WinboxSubMenu('Certificates', '/certificate', 'name', 'common-name', ['name', 'common-name', 'fingerprint', 'invalid-after']),
    WinboxSubMenu('Identity', '/system/identity', 'name', null, ['name']),
    WinboxSubMenu('Watchdog', '/system/watchdog', 'watch-address', 'watchdog-timer', ['watch-address', 'watchdog-timer', 'ping-timeout']),
    WinboxSubMenu('Auto Upgrade', '/system/upgrade', 'status', null, ['status']),
    WinboxSubMenu('Reboot Router', 'SYSTEM_REBOOT', 'Reboot Perangkat MikroTik', null),
    WinboxSubMenu('Shutdown Router', 'SYSTEM_SHUTDOWN', 'Matikan Router MikroTik', null),
  ]),
  WinboxCategory('Tools', Icons.terminal_rounded, [
    WinboxSubMenu('Ping Diagnostic', 'PING_TOOL', 'Ping ICMP Tool', null),
    WinboxSubMenu('Traceroute', 'TRACEROUTE_TOOL', 'Traceroute Network Path', null),
    WinboxSubMenu('Profile CPU', 'PROFILE_TOOL', 'CPU Usage Per Process', null),
    WinboxSubMenu('Netwatch', '/tool/netwatch', 'host', 'status', ['host', 'interval', 'timeout', 'status']),
    WinboxSubMenu('IP Scan', '/tool/ip-scan', 'address-range', 'interface', ['address-range', 'interface']),
    WinboxSubMenu('Bandwidth Test', '/tool/bandwidth-test', 'direction', 'protocol', ['direction', 'protocol']),
    WinboxSubMenu('Packet Sniffer', '/tool/sniffer', 'streaming-server', 'file-name', ['streaming-server', 'file-name', 'file-limit']),
    WinboxSubMenu('Email Config', '/tool/e-mail', 'server', 'from', ['server', 'port', 'user', 'from']),
    WinboxSubMenu('SMS Config', '/tool/sms', 'port', 'channel', ['port', 'channel']),
    WinboxSubMenu('MAC Server', '/tool/mac-server', 'interface', null, ['interface']),
    WinboxSubMenu('New Terminal', 'CLI_TOOL', 'Command Line Runner', null),
  ]),
];
