// ==============================================================================
// POCKET WINBOX - MASTER BLUEPRINT MENU (PARITAS 1:1 DENGAN WINBOX ASLI)
// ==============================================================================
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
  const WinboxSubMenu(this.title, this.path, this.primaryField,
      this.secondaryField,
      [this.displayColumns = const []]);
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
  // ============ 1. QUICK SET (seperti Winbox) ============
  WinboxCategory('Quick Set', Icons.tune_rounded, [
    WinboxSubMenu('Quick Set', 'QUICK_SET', 'Quick Configuration', null),
  ]),

  // ============ 2. CAPsMAN ============
  WinboxCategory('CAPsMAN', Icons.cell_tower_rounded, [
    WinboxSubMenu('Manager', '/caps-man/manager', 'enabled', 'upgrade-policy',
        ['enabled', 'upgrade-policy', 'certificate', 'ca-certificate']),
    WinboxSubMenu('Configuration', '/caps-man/configuration', 'name', 'ssid',
        ['name', 'ssid', 'country', 'security', 'datapath']),
    WinboxSubMenu('Datapath', '/caps-man/datapath', 'name', 'bridge',
        ['name', 'bridge', 'local-forwarding', 'client-to-client-forwarding', 'vlan-id']),
    WinboxSubMenu('Security', '/caps-man/security', 'name', 'authentication-types',
        ['name', 'authentication-types', 'encryption', 'group-encryption']),
    WinboxSubMenu('Provisioning', '/caps-man/provisioning', 'radio-mac', 'master-configuration',
        ['radio-mac', 'ip-address-ranges', 'master-configuration', 'slave-configurations', 'action']),
    WinboxSubMenu('Access List', '/caps-man/access-list', 'mac-address', 'action',
        ['mac-address', 'interface', 'signal-range', 'action', 'time']),
    WinboxSubMenu('Interfaces', '/caps-man/interface', 'name', 'radio-mac',
        ['name', 'radio-mac', 'current-state', 'channel', 'current-registered-clients']),
    WinboxSubMenu('Registration Table', '/caps-man/registration-table', 'mac-address', 'interface',
        ['mac-address', 'interface', 'ssid', 'tx-rate', 'rx-rate', 'uptime']),
  ]),

  // ============ 3. INTERFACES ============
  WinboxCategory('Interfaces', Icons.lan_rounded, [
    WinboxSubMenu('Interface List', '/interface', 'name', 'type',
        ['name', 'type', 'actual-mtu', 'mac-address', 'running', 'disabled', 'rx-byte', 'tx-byte']),
    WinboxSubMenu('Ethernet', '/interface/ethernet', 'name', 'mac-address',
        ['name', 'mac-address', 'speed', 'full-duplex', 'auto-negotiation']),
    WinboxSubMenu('VLAN', '/interface/vlan', 'name', 'vlan-id',
        ['name', 'vlan-id', 'interface', 'mtu', 'use-service-tag']),
    WinboxSubMenu('Bridge', '/interface/bridge', 'name', 'mac-address',
        ['name', 'mac-address', 'mtu', 'fast-forward', 'vlan-filtering']),
    WinboxSubMenu('Bonding', '/interface/bonding', 'name', 'mode',
        ['name', 'slaves', 'mode', 'link-monitoring']),
    WinboxSubMenu('VRRP', '/interface/vrrp', 'name', 'vrid',
        ['name', 'interface', 'vrid', 'priority', 'interval']),
    WinboxSubMenu('EoIP Tunnel', '/interface/eoip', 'name', 'remote-address',
        ['name', 'remote-address', 'tunnel-id', 'mtu']),
    WinboxSubMenu('GRE Tunnel', '/interface/gre', 'name', 'remote-address',
        ['name', 'remote-address', 'dscp', 'mtu']),
    WinboxSubMenu('IPIP Tunnel', '/interface/ipip', 'name', 'remote-address',
        ['name', 'remote-address', 'dscp', 'mtu']),
    WinboxSubMenu('L2TP Client', '/interface/l2tp-client', 'name', 'connect-to',
        ['name', 'connect-to', 'user', 'profile']),
    WinboxSubMenu('L2TP Server', '/interface/l2tp-server/server', 'enabled', 'default-profile',
        ['enabled', 'default-profile', 'max-mtu', 'authentication']),
    WinboxSubMenu('PPPoE Client', '/interface/pppoe-client', 'name', 'user',
        ['name', 'interface', 'user', 'service-name']),
    WinboxSubMenu('PPTP Client', '/interface/pptp-client', 'name', 'connect-to',
        ['name', 'connect-to', 'user', 'profile']),
    WinboxSubMenu('SSTP Client', '/interface/sstp-client', 'name', 'connect-to',
        ['name', 'connect-to', 'user', 'profile']),
    WinboxSubMenu('VXLAN', '/interface/vxlan', 'name', 'vni',
        ['name', 'vni', 'port', 'mtu']),
    WinboxSubMenu('VPLS', '/interface/vpls', 'name', 'remote-peer',
        ['name', 'remote-peer', 'vpls-id', 'mac-address']),
    WinboxSubMenu('WireGuard', '/interface/wireguard', 'name', 'listen-port',
        ['name', 'listen-port', 'public-key', 'mtu']),
    WinboxSubMenu('WireGuard Peers', '/interface/wireguard/peers', 'interface', 'public-key',
        ['interface', 'public-key', 'allowed-address', 'endpoint-address']),
    WinboxSubMenu('LTE', '/interface/lte', 'name', 'pin',
        ['name', 'pin', 'network-mode', 'modem-signal']),
    WinboxSubMenu('5G', '/interface/5g', 'name', 'pin',
        ['name', 'pin', 'network-mode']),
  ]),

  // ============ 4. WIRELESS (BARU - kategori penuh seperti Winbox) ============
  WinboxCategory('Wireless', Icons.wifi_tethering_rounded, [
    WinboxSubMenu('Wireless Interfaces', '/interface/wireless', 'name', 'ssid',
        ['name', 'ssid', 'band', 'frequency', 'mode', 'radio-name', 'rx-signal', 'disabled']),
    WinboxSubMenu('Security Profiles', '/interface/wireless/security-profiles', 'name', 'mode',
        ['name', 'mode', 'authentication-types', 'unicast-ciphers', 'group-ciphers']),
    WinboxSubMenu('Access List', '/interface/wireless/access-list', 'mac-address', 'interface',
        ['mac-address', 'interface', 'signal-range', 'authentication', 'forwarding']),
    WinboxSubMenu('Connect List', '/interface/wireless/connect-list', 'interface', 'mac-address',
        ['interface', 'mac-address', 'connect', 'security-profile']),
    WinboxSubMenu('Registration Table', '/interface/wireless/registration-table', 'mac-address', 'interface',
        ['mac-address', 'interface', 'ssid', 'tx-rate', 'rx-rate', 'uptime', 'signal-strength']),
    WinboxSubMenu('Snooper (Scan AP)', '/interface/wireless/snooper', 'ssid', 'bssid',
        ['ssid', 'bssid', 'channel', 'signal', 'security']),
    WinboxSubMenu('Sniff Settings', '/interface/wireless/sniff', 'interface', 'channel-time',
        ['interface', 'streaming-enabled', 'streaming-server', 'channel-time']),
    WinboxSubMenu('CAP', '/interface/wireless/cap', 'enabled', 'caps-man-addresses',
        ['enabled', 'interfaces', 'caps-man-addresses', 'certificate']),
  ]),

  // ============ 5. BRIDGE ============
  WinboxCategory('Bridge', Icons.alt_route_rounded, [
    WinboxSubMenu('Bridges', '/interface/bridge', 'name', 'mac-address',
        ['name', 'mac-address', 'mtu', 'vlan-filtering', 'protocol-mode']),
    WinboxSubMenu('Ports', '/interface/bridge/port', 'interface', 'bridge',
        ['interface', 'bridge', 'priority', 'path-cost', 'pvid', 'edge']),
    WinboxSubMenu('VLANs', '/interface/bridge/vlan', 'bridge', 'vlan-ids',
        ['bridge', 'vlan-ids', 'tagged', 'untagged']),
    WinboxSubMenu('Hosts', '/interface/bridge/host', 'mac-address', 'bridge',
        ['mac-address', 'bridge', 'on-interface', 'age', 'local']),
    WinboxSubMenu('Bridge ARP', '/interface/bridge/arp', 'address', 'mac-address',
        ['address', 'mac-address', 'interface']),
    WinboxSubMenu('Bridge Settings', '/interface/bridge/settings', 'use-ip-firewall', 'allow-fast-path',
        ['use-ip-firewall', 'allow-fast-path']),
  ]),

  // ============ 6. PPP ============
  WinboxCategory('PPP', Icons.people_outline_rounded, [
    WinboxSubMenu('Profiles', '/ppp/profile', 'name', 'local-address',
        ['name', 'local-address', 'remote-address', 'rate-limit', 'dns-server']),
    WinboxSubMenu('Secrets', '/ppp/secret', 'name', 'profile',
        ['name', 'service', 'profile', 'local-address', 'remote-address', 'last-logged-out']),
    WinboxSubMenu('Active Connections', '/ppp/active', 'name', 'address',
        ['name', 'service', 'caller-id', 'address', 'uptime']),
    WinboxSubMenu('AAA Settings', '/ppp/aaa', 'use-radius', null,
        ['use-radius', 'accounting', 'interim-update']),
  ]),

  // ============ 7. MESH (BARU) ============
  WinboxCategory('Mesh', Icons.device_hub_rounded, [
    WinboxSubMenu('Mesh Interfaces', '/mesh', 'name', 'mesh-id',
        ['name', 'mesh-id', 'interface', 'metric', 'disabled']),
    WinboxSubMenu('Mesh Portal', '/mesh/portal', 'name', 'bridge',
        ['name', 'bridge', 'path-cost', 'disabled']),
  ]),

  // ============ 8. IP ============
  WinboxCategory('IP', Icons.language_rounded, [
    WinboxSubMenu('Addresses', '/ip/address', 'address', 'interface',
        ['address', 'network', 'interface', 'actual-interface', 'disabled']),
    WinboxSubMenu('ARP Table', '/ip/arp', 'address', 'mac-address',
        ['address', 'mac-address', 'interface', 'published', 'complete']),
    WinboxSubMenu('IP Pool', '/ip/pool', 'name', 'ranges', ['name', 'ranges', 'next-pool']),
    WinboxSubMenu('DNS Settings', '/ip/dns', 'servers', 'dynamic-servers',
        ['servers', 'dynamic-servers', 'allow-remote-requests', 'cache-size']),
    WinboxSubMenu('DNS Static', '/ip/dns/static', 'name', 'address',
        ['name', 'address', 'ttl', 'type']),
    WinboxSubMenu('DHCP Client', '/ip/dhcp-client', 'interface', 'status',
        ['interface', 'use-peer-dns', 'status', 'address', 'gateway']),
    WinboxSubMenu('DHCP Relay', '/ip/dhcp-relay', 'name', 'interface',
        ['name', 'interface', 'dhcp-server']),
    WinboxSubMenu('DHCP Server', '/ip/dhcp-server', 'name', 'interface',
        ['name', 'interface', 'lease-time', 'address-pool', 'disabled']),
    WinboxSubMenu('DHCP Networks', '/ip/dhcp-server/network', 'address', 'gateway',
        ['address', 'gateway', 'dns-server', 'domain']),
    WinboxSubMenu('DHCP Leases', '/ip/dhcp-server/lease', 'address', 'host-name',
        ['address', 'mac-address', 'host-name', 'server', 'status', 'expires-after']),
    WinboxSubMenu('Hotspot Servers', '/ip/hotspot', 'name', 'interface',
        ['name', 'interface', 'address-pool', 'profile']),
    WinboxSubMenu('Hotspot Profiles', '/ip/hotspot/profile', 'name', 'hotspot-address',
        ['name', 'hotspot-address', 'dns-name', 'html-directory']),
    WinboxSubMenu('Hotspot User Profiles', '/ip/hotspot/user/profile', 'name', 'shared-users',
        ['name', 'shared-users', 'rate-limit', 'transparent-proxy']),
    WinboxSubMenu('Hotspot Walled Garden', '/ip/hotspot/walled-garden', 'dst-host', 'action',
        ['dst-host', 'action', 'path']),
    WinboxSubMenu('Hotspot Active', '/ip/hotspot/active', 'user', 'address',
        ['user', 'address', 'mac-address', 'uptime', 'session-time-left']),
    WinboxSubMenu('Hotspot Users', '/ip/hotspot/user', 'name', 'profile',
        ['name', 'password', 'profile', 'uptime', 'bytes-in', 'bytes-out']),
    WinboxSubMenu('Services', '/ip/service', 'name', 'port',
        ['name', 'port', 'address', 'certificate', 'disabled']),
    WinboxSubMenu('SSH', '/ip/ssh', 'forwarding-enabled', null,
        ['forwarding-enabled', 'always-allow-password-login']),
    WinboxSubMenu('SOCKS', '/ip/socks', 'enabled', 'port',
        ['enabled', 'port', 'connection-idle-timeout']),
    WinboxSubMenu('Web Proxy', '/ip/proxy', 'enabled', 'port',
        ['enabled', 'port', 'cache-administrator', 'max-cache-size']),
    WinboxSubMenu('UPnP', '/ip/upnp', 'enabled', null,
        ['enabled', 'allow-disable-external-interface']),
    WinboxSubMenu('SMB', '/ip/smb', 'enabled', 'domain', ['enabled', 'domain', 'comment']),
    WinboxSubMenu('TFTP', '/ip/tftp', 'req-filename', 'real-filename',
        ['req-filename', 'real-filename', 'allow']),
    WinboxSubMenu('Cloud DDNS', '/ip/cloud', 'dns-name', 'status',
        ['dns-name', 'public-address', 'status', 'update-time']),
    WinboxSubMenu('Neighbors', '/ip/neighbor', 'identity', 'address',
        ['interface', 'address', 'mac-address', 'identity', 'platform', 'version']),
  ]),

  // ============ 9. IPv6 ============
  WinboxCategory('IPv6', Icons.public_rounded, [
    WinboxSubMenu('Addresses', '/ipv6/address', 'address', 'interface',
        ['address', 'from-pool', 'interface', 'actual-interface']),
    WinboxSubMenu('IP Pools', '/ipv6/pool', 'name', 'prefix',
        ['name', 'prefix', 'prefix-length']),
    WinboxSubMenu('ND (Neighbor Disc.)', '/ipv6/nd', 'interface', 'ra-interval',
        ['interface', 'ra-interval', 'ra-lifetime']),
    WinboxSubMenu('DHCPv6 Client', '/ipv6/dhcp-client', 'interface', 'pool-name',
        ['interface', 'status', 'pool-name', 'prefix']),
    WinboxSubMenu('DHCPv6 Server', '/ipv6/dhcp-server', 'name', 'interface',
        ['name', 'interface', 'address-pool']),
    WinboxSubMenu('IPv6 Routes', '/ipv6/route', 'dst-address', 'gateway',
        ['dst-address', 'gateway', 'distance', 'metric']),
    WinboxSubMenu('Firewall Filter', '/ipv6/firewall/filter', 'chain', 'action',
        ['chain', 'action', 'src-address', 'dst-address']),
    WinboxSubMenu('Firewall NAT', '/ipv6/firewall/nat', 'chain', 'action',
        ['chain', 'action', 'src-address', 'dst-address']),
    WinboxSubMenu('Firewall Mangle', '/ipv6/firewall/mangle', 'chain', 'action',
        ['chain', 'action', 'new-packet-mark']),
  ]),

  // ============ 10. MPLS (BARU) ============
  WinboxCategory('MPLS', Icons.call_split_rounded, [
    WinboxSubMenu('MPLS Settings', '/mpls', 'propagate-ttl', null,
        ['propagate-ttl', 'dynamic-label-space']),
    WinboxSubMenu('MPLS Interfaces', '/mpls/interface', 'interface', 'mpls-mtu',
        ['interface', 'mpls-mtu', 'disabled']),
    WinboxSubMenu('LDP', '/mpls/ldp', 'enabled', 'lsr-id',
        ['enabled', 'lsr-id', 'transport-address', 'loop-detect']),
    WinboxSubMenu('LDP Interfaces', '/mpls/ldp/interface', 'interface', 'hello-interval',
        ['interface', 'hello-interval', 'hold-time', 'disabled']),
    WinboxSubMenu('LDP Neighbors', '/mpls/ldp/neighbor', 'lsr-id', 'transport-address',
        ['lsr-id', 'transport-address', 'state', 'uptime']),
  ]),

  // ============ 11. ROUTING ============
  WinboxCategory('Routing', Icons.directions_rounded, [
    WinboxSubMenu('Static Routes', '/ip/route', 'dst-address', 'gateway',
        ['dst-address', 'gateway', 'distance', 'scope', 'pref-src', 'active']),
    WinboxSubMenu('OSPF Instances', '/routing/ospf/instance', 'name', 'router-id',
        ['name', 'router-id', 'version']),
    WinboxSubMenu('OSPF Areas', '/routing/ospf/area', 'name', 'instance',
        ['name', 'instance', 'area-id']),
    WinboxSubMenu('OSPF Interfaces', '/routing/ospf/interface-template', 'area', 'interfaces',
        ['area', 'interfaces', 'cost', 'priority']),
    WinboxSubMenu('OSPF Neighbors', '/routing/ospf/neighbor', 'router-id', 'address',
        ['router-id', 'address', 'state', 'priority']),
    WinboxSubMenu('BGP Connections', '/routing/bgp/connection', 'name', 'remote.address',
        ['name', 'remote.address', 'remote.as', 'local.role']),
    WinboxSubMenu('BGP Sessions', '/routing/bgp/session', 'name', 'remote.address',
        ['name', 'remote.address', 'state', 'uptime']),
    WinboxSubMenu('RIP Instances', '/routing/rip/instance', 'name', 'version',
        ['name', 'version']),
    WinboxSubMenu('BFD Configuration', '/routing/bfd/configuration', 'name', null,
        ['name', 'min-rx', 'min-tx']),
    WinboxSubMenu('Routing Filters', '/routing/filter/rule', 'chain', 'rule',
        ['chain', 'rule']),
    WinboxSubMenu('VRF Tables', '/ip/route/vrf', 'name', 'interfaces',
        ['name', 'interfaces', 'route-distinguisher']),
  ]),

  // ============ 12. FIREWALL ============
  WinboxCategory('Firewall', Icons.security_rounded, [
    WinboxSubMenu('Filter Rules', '/ip/firewall/filter', 'chain', 'action',
        ['chain', 'action', 'src-address', 'dst-address', 'protocol', 'dst-port', 'comment']),
    WinboxSubMenu('NAT Rules', '/ip/firewall/nat', 'chain', 'action',
        ['chain', 'action', 'to-addresses', 'to-ports', 'out-interface', 'comment']),
    WinboxSubMenu('Mangle Rules', '/ip/firewall/mangle', 'chain', 'action',
        ['chain', 'action', 'new-packet-mark', 'new-connection-mark', 'passthrough']),
    WinboxSubMenu('Raw Rules', '/ip/firewall/raw', 'chain', 'action',
        ['chain', 'action', 'src-address', 'dst-address', 'comment']),
    WinboxSubMenu('Connections', '/ip/firewall/connection', 'src-address', 'dst-address',
        ['protocol', 'src-address', 'dst-address', 'reply-src-address', 'tcp-state']),
    WinboxSubMenu('Address Lists', '/ip/firewall/address-list', 'list', 'address',
        ['list', 'address', 'timeout', 'comment']),
    WinboxSubMenu('Service Ports', '/ip/firewall/service-port', 'name', 'ports',
        ['name', 'ports', 'disabled']),
  ]),

  // ============ 13. SYSTEM ============
  WinboxCategory('System', Icons.dns_rounded, [
    WinboxSubMenu('System Identity', '/system/identity', 'name', null, ['name']),
    WinboxSubMenu('Resources', '/system/resource', 'board-name', 'version',
        ['board-name', 'version', 'cpu-load', 'free-memory', 'total-memory', 'uptime']),
    WinboxSubMenu('Health', '/system/health', 'name', 'value', ['name', 'value', 'type']),
    WinboxSubMenu('RouterBOARD', '/system/routerboard', 'model', 'current-firmware',
        ['routerboard', 'model', 'serial-number', 'current-firmware', 'upgrade-firmware']),
    WinboxSubMenu('Backups', '/system/backup', 'name', 'size',
        ['name', 'size', 'creation-time']),
    WinboxSubMenu('Users', '/user', 'name', 'group', ['name', 'group', 'last-logged-in']),
    WinboxSubMenu('User Groups', '/user/group', 'name', 'policy', ['name', 'policy']),
    WinboxSubMenu('User SSH Keys', '/user/ssh-keys', 'user', 'bits',
        ['user', 'bits', 'key-owner']),
    WinboxSubMenu('Active Users', '/user/active', 'name', 'via',
        ['name', 'when', 'via', 'address']),
    WinboxSubMenu('Certificates', '/certificate', 'name', 'common-name',
        ['name', 'common-name', 'fingerprint', 'invalid-after']),
    WinboxSubMenu('Clock', '/system/clock', 'time', 'date',
        ['time', 'date', 'time-zone-name']),
    WinboxSubMenu('NTP Client', '/system/ntp/client', 'enabled', 'status',
        ['enabled', 'mode', 'server-dns-names', 'status']),
    WinboxSubMenu('NTP Server', '/system/ntp/server', 'enabled', 'mode',
        ['enabled', 'mode', 'multicast']),
    WinboxSubMenu('Scheduler', '/system/scheduler', 'name', 'interval',
        ['name', 'start-date', 'start-time', 'interval', 'next-run']),
    WinboxSubMenu('Scripts', '/system/script', 'name', 'owner',
        ['name', 'owner', 'last-started', 'run-count']),
    WinboxSubMenu('Licenses', '/system/license', 'software-id', 'nlevel',
        ['software-id', 'nlevel', 'features']),
    WinboxSubMenu('Packages', '/system/package', 'name', 'version',
        ['name', 'version', 'build-time']),
    WinboxSubMenu('Make Supout.rif', 'SYSTEM_SUPOUT', 'Buat file dukungan diagnostik', null),
    WinboxSubMenu('Reboot Router', 'SYSTEM_REBOOT', 'Reboot Perangkat MikroTik', null),
    WinboxSubMenu('Shutdown Router', 'SYSTEM_SHUTDOWN', 'Matikan Router MikroTik', null),
  ]),

  // ============ 14. QUEUES ============
  WinboxCategory('Queues', Icons.network_check_rounded, [
    WinboxSubMenu('Simple Queues', '/queue/simple', 'name', 'max-limit',
        ['name', 'target', 'max-limit', 'bytes', 'total-bytes', 'comment']),
    WinboxSubMenu('Queue Tree', '/queue/tree', 'name', 'parent',
        ['name', 'parent', 'packet-mark', 'max-limit', 'priority']),
    WinboxSubMenu('Queue Types', '/queue/type', 'name', 'kind', ['name', 'kind']),
    WinboxSubMenu('Interface Queues', '/queue/interface', 'interface', 'queue',
        ['interface', 'queue']),
  ]),

  // ============ 15. DOT1X (BARU) ============
  WinboxCategory('Dot1X', Icons.vpn_key_rounded, [
    WinboxSubMenu('Dot1X Client', '/dot1x/client', 'interface', 'status',
        ['interface', 'status', 'controlled-port']),
    WinboxSubMenu('Dot1X Server', '/dot1x/server', 'interface', 'auth-types',
        ['interface', 'auth-types', 'guest-if-disabled']),
  ]),

  // ============ 16. FILES (BARU - top-level seperti Winbox) ============
  WinboxCategory('Files', Icons.folder_rounded, [
    WinboxSubMenu('Files', '/file', 'name', 'size',
        ['name', 'type', 'size', 'creation-time']),
  ]),

  // ============ 17. LOG (BARU - top-level seperti Winbox) ============
  WinboxCategory('Log', Icons.receipt_long_rounded, [
    WinboxSubMenu('System Logs', '/log', 'time', 'message',
        ['time', 'topics', 'message']),
    WinboxSubMenu('Logging Rules', '/system/logging', 'topics', 'action',
        ['topics', 'action', 'prefix']),
    WinboxSubMenu('Logging Actions', '/system/logging/action', 'name', 'target',
        ['name', 'target', 'remember']),
  ]),

  // ============ 18. RADIUS (BARU - top-level seperti Winbox) ============
  WinboxCategory('RADIUS', Icons.account_tree_rounded, [
    WinboxSubMenu('RADIUS Clients', '/radius', 'service', 'address',
        ['service', 'address', 'secret', 'timeout']),
    WinboxSubMenu('Incoming', '/radius/incoming', 'accept', null, ['accept']),
  ]),

  // ============ 19. IPSEC ============
  WinboxCategory('IPsec', Icons.vpn_lock_rounded, [
    WinboxSubMenu('Peers', '/ip/ipsec/peer', 'name', 'address',
        ['name', 'address', 'profile', 'exchange-mode']),
    WinboxSubMenu('Identities', '/ip/ipsec/identity', 'peer', 'auth-method',
        ['peer', 'auth-method', 'secret', 'my-id']),
    WinboxSubMenu('Proposals', '/ip/ipsec/proposal', 'name', 'auth-algorithms',
        ['name', 'auth-algorithms', 'enc-algorithms', 'lifetime']),
    WinboxSubMenu('Settings', '/ip/ipsec/settings', 'accounting', null,
        ['accounting', 'interim-update']),
    WinboxSubMenu('Policies', '/ip/ipsec/policy', 'src-address', 'dst-address',
        ['src-address', 'dst-address', 'action', 'proposal']),
    WinboxSubMenu('Active Connections', '/ip/ipsec/active-peers', 'address', 'state',
        ['address', 'side', 'uptime', 'state']),
    WinboxSubMenu('Mode Configs', '/ip/ipsec/mode-config', 'name', 'address-pool',
        ['name', 'address-pool', 'address', 'system-dns']),
  ]),

  // ============ 20. TOOLS ============
  WinboxCategory('Tools', Icons.terminal_rounded, [
    WinboxSubMenu('New Terminal (CLI)', 'CLI_TOOL', 'Command Line Runner', null),
    WinboxSubMenu('Ping Diagnostic', 'PING_TOOL', 'Ping ICMP Diagnostic', null),
    WinboxSubMenu('Traceroute', 'TRACEROUTE_TOOL', 'Traceroute Network Path', null),
    WinboxSubMenu('Bandwidth Test', '/tool/bandwidth-test', 'direction', 'protocol',
        ['direction', 'protocol']),
    WinboxSubMenu('Torch (Sniffer)', '/tool/torch', 'interface', 'protocol',
        ['interface', 'protocol', 'src-address', 'dst-address']),
    WinboxSubMenu('Netwatch', '/tool/netwatch', 'host', 'status',
        ['host', 'interval', 'timeout', 'status']),
    WinboxSubMenu('Packet Sniffer', '/tool/sniffer', 'streaming-server', 'file-name',
        ['streaming-server', 'file-name', 'file-limit']),
    WinboxSubMenu('Traffic Flow', '/tool/traffic-flow', 'enabled', 'interfaces',
        ['enabled', 'interfaces', 'cache-entries']),
    WinboxSubMenu('MAC Ping', '/tool/mac-ping', 'mac-address', 'interface',
        ['mac-address', 'interface']),
    WinboxSubMenu('MAC Telnet', '/tool/mac-telnet', 'mac-address', null,
        ['mac-address', 'interface']),
    WinboxSubMenu('MAC Winbox Server', '/tool/mac-server/mac-winbox', 'interface', null,
        ['interface']),
    WinboxSubMenu('Graphing', '/tool/graphing', 'store-every', null, ['store-every']),
    WinboxSubMenu('Wake on LAN', '/tool/wol', 'mac', 'interface', ['mac', 'interface']),
    WinboxSubMenu('Watchdog', '/system/watchdog', 'watch-address', 'watchdog-timer',
        ['watch-address', 'watchdog-timer', 'ping-timeout']),
    WinboxSubMenu('User Manager', '/tool/user-manager', 'customer', null,
        ['customer', 'user', 'router']),
    WinboxSubMenu('Email Settings', '/tool/e-mail', 'server', 'from',
        ['server', 'port', 'user', 'from']),
    WinboxSubMenu('CPU Profile', 'PROFILE_TOOL', 'CPU Usage Per Process', null),
  ]),

  // ============ 21. DUDE (BARU) ============
  WinboxCategory('Dude', Icons.insights_rounded, [
    WinboxSubMenu('Dude Settings', '/dude', 'enabled', 'status',
        ['enabled', 'status']),
    WinboxSubMenu('Devices', '/dude/device', 'name', 'address',
        ['name', 'address', 'type', 'status', 'down-count']),
    WinboxSubMenu('Maps', '/dude/map', 'name', 'parent', ['name', 'parent', 'background']),
    WinboxSubMenu('Notifications', '/dude/notification', 'name', 'type',
        ['name', 'type', 'tool']),
  ]),

  // ============ 22. HARDWARE & IOT ============
  WinboxCategory('Hardware & IoT', Icons.memory_rounded, [
    WinboxSubMenu('Serial Ports', '/port', 'name', 'device',
        ['name', 'device', 'baud-rate', 'data-bits', 'parity', 'stop-bits']),
    WinboxSubMenu('GPS Tracking', '/system/gps', 'port', null,
        ['port', 'baud-rate', 'polling-interval']),
    WinboxSubMenu('LCD Screen', '/system/lcd', 'enabled', 'port',
        ['enabled', 'port', 'contrast']),
    WinboxSubMenu('UPS Monitor', '/system/ups', 'name', 'port',
        ['name', 'port', 'offline-time', 'min-valid-voltage']),
    WinboxSubMenu('LED Settings', '/system/leds', 'leds', 'interface',
        ['leds', 'interface', 'type']),
  ]),

  // ============ 23. SWITCH CHIP ============
  WinboxCategory('Switch Chip', Icons.switch_left_rounded, [
    WinboxSubMenu('Switch Ports', '/interface/ethernet/switch/port', 'name', 'switch',
        ['name', 'switch', 'vlan-mode', 'vlan-header', 'default-vlan-id']),
    WinboxSubMenu('Switch VLANs', '/interface/ethernet/switch/vlan', 'switch', 'ports',
        ['switch', 'ports', 'vlan-id']),
    WinboxSubMenu('Hardware ACLs', '/interface/ethernet/switch/rule', 'switch', 'action',
        ['switch', 'src-mac-address', 'dst-mac-address', 'action']),
  ]),

  // ============ 24. V7 & NEXT-GEN ============
  WinboxCategory('v7 & Next-Gen', Icons.auto_awesome_rounded, [
    WinboxSubMenu('Containers (Docker)', '/container', 'name', 'status',
        ['name', 'tag', 'image', 'status', 'mounts']),
    WinboxSubMenu('Container Mounts', '/container/mounts', 'name', 'src',
        ['name', 'src', 'dst', 'mode']),
    WinboxSubMenu('Container Configs', '/container/configs', 'name', 'type',
        ['name', 'type', 'value']),
    WinboxSubMenu('Modern WiFi (AX/Wave2)', '/interface/wifi', 'name', 'ssid',
        ['name', 'ssid', 'channel', 'security', 'configuration']),
    WinboxSubMenu('WiFi Security', '/interface/wifi/security', 'name', 'authentication-types',
        ['name', 'passphrase', 'authentication-types']),
    WinboxSubMenu('WiFi Configs', '/interface/wifi/configuration', 'name', 'ssid',
        ['name', 'ssid', 'country', 'dtim-interval']),
    WinboxSubMenu('ZeroTier', '/interface/zerotier', 'name', 'identity',
        ['name', 'identity', 'comment']),
    WinboxSubMenu('BGP Templates', '/routing/bgp/template', 'name', 'address-family',
        ['name', 'address-family', 'as', 'role']),
  ]),

  // ============ 25. ISP & INTEGRATIONS ============
  WinboxCategory('ISP & Integrations', Icons.hub_rounded, [
    WinboxSubMenu('SNMP Agent', '/snmp', 'enabled', 'contact',
        ['enabled', 'contact', 'location', 'trap-targets']),
    WinboxSubMenu('SNMP Communities', '/snmp/community', 'name', 'addresses',
        ['name', 'addresses', 'read-access', 'write-access', 'authentication-password']),
    WinboxSubMenu('IGMP Proxy', '/routing/igmp-proxy', 'name', 'upstream-network',
        ['name', 'interface', 'upstream-network', 'alternative-subnets']),
    WinboxSubMenu('IP Accounting', '/ip/accounting', 'enabled', 'threshold',
        ['enabled', 'threshold', 'accounting-local-networks']),
    WinboxSubMenu('Bandwidth Server', '/tool/bandwidth-server', 'enabled', 'authenticate',
        ['enabled', 'authenticate', 'max-rx-speed', 'max-tx-speed']),
    WinboxSubMenu('RoMon Server', '/tool/mac-server/romon', 'enabled', null, ['enabled']),
  ]),
];