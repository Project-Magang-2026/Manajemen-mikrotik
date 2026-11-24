enum ApiProtocol {
  routerOsApi8728,
  restApiHttp,
  restApiHttps,
}

extension ApiProtocolExt on ApiProtocol {
  String get label {
    switch (this) {
      case ApiProtocol.routerOsApi8728:
        return 'RouterOS API (Port 8728)';
      case ApiProtocol.restApiHttp:
        return 'REST API HTTP (Port 80)';
      case ApiProtocol.restApiHttps:
        return 'REST API HTTPS (Port 443)';
    }
  }

  int get defaultPort {
    switch (this) {
      case ApiProtocol.routerOsApi8728:
        return 8728;
      case ApiProtocol.restApiHttp:
        return 80;
      case ApiProtocol.restApiHttps:
        return 443;
    }
  }
}

enum AppRole {
  user,
  technician,
}

enum LoginRolePreference {
  auto,
  technician,
  user,
}

extension LoginRolePreferenceExt on LoginRolePreference {
  String get label {
    switch (this) {
      case LoginRolePreference.auto:
        return 'Otomatis (Sesuai Izin Akun)';
      case LoginRolePreference.technician:
        return 'Masuk sebagai Teknisi';
      case LoginRolePreference.user:
        return 'Masuk sebagai User';
    }
  }
}

class RouterProfile {
  final String id;
  final String label;
  final String host;
  final int port;
  final String username;
  final String password;
  final ApiProtocol protocol;
  final LoginRolePreference rolePreference;

  RouterProfile({
    required this.id,
    required this.label,
    required this.host,
    required this.port,
    required this.username,
    required this.password,
    required this.protocol,
    this.rolePreference = LoginRolePreference.auto,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'host': host,
        'port': port,
        'username': username,
        'password': password,
        'protocol': protocol.name,
        'rolePreference': rolePreference.name,
      };

  factory RouterProfile.fromJson(Map<String, dynamic> json) {
    return RouterProfile(
      id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      label: json['label'] ?? json['host'] ?? 'Router',
      host: json['host'] ?? '',
      port: json['port'] ?? 8728,
      username: json['username'] ?? '',
      password: json['password'] ?? '',
      protocol: ApiProtocol.values.firstWhere(
        (e) => e.name == json['protocol'],
        orElse: () => ApiProtocol.routerOsApi8728,
      ),
      rolePreference: LoginRolePreference.values.firstWhere(
        (e) => e.name == json['rolePreference'],
        orElse: () => LoginRolePreference.auto,
      ),
    );
  }
}

class UserRoleInfo {
  final String username;
  final String groupName;
  final List<String> policies;
  final AppRole role;
  final bool canWrite;
  final bool hasFull;
  final bool canReboot;
  final bool canManageUsers;
  final bool canRunTest;

  UserRoleInfo({
    required this.username,
    required this.groupName,
    required this.policies,
    required this.role,
    required this.canWrite,
    required this.hasFull,
    required this.canReboot,
    required this.canManageUsers,
    required this.canRunTest,
  });

  bool get isTechnician => role == AppRole.technician;
  bool get isUser => role == AppRole.user;
  bool get isReadOnly => !canWrite;

  String get roleBadge {
    if (isTechnician) {
      return hasFull ? 'TEKNISI (FULL)' : 'TEKNISI (WRITE)';
    }
    return 'MODE USER';
  }
}

class WifiInterfaceInfo {
  final String id;
  final String name;
  final String ssid;
  final String password;
  final String securityProfile;
  final bool isRosV7Wifi;
  final bool disabled;

  WifiInterfaceInfo({
    required this.id,
    required this.name,
    required this.ssid,
    required this.password,
    required this.securityProfile,
    required this.isRosV7Wifi,
    required this.disabled,
  });
}

class ConnectedDevice {
  final String macAddress;
  final String ipAddress;
  final String hostName;
  final String source;
  final bool isBlocked;

  ConnectedDevice({
    required this.macAddress,
    required this.ipAddress,
    required this.hostName,
    required this.source,
    required this.isBlocked,
  });
}

class StaticHostDevice {
  final String ipAddress;
  final String macAddress;
  final String interfaceName;
  final String customerName;
  final String maxLimit;
  final String currentRate;
  final bool isBlockedByIp;
  final bool isBlockedByMac;
  final bool isUnqueuedAnomaly;
  final String? comment;

  StaticHostDevice({
    required this.ipAddress,
    required this.macAddress,
    required this.interfaceName,
    required this.customerName,
    required this.maxLimit,
    required this.currentRate,
    required this.isBlockedByIp,
    required this.isBlockedByMac,
    required this.isUnqueuedAnomaly,
    this.comment,
  });

  bool get isBlocked => isBlockedByIp || isBlockedByMac;
}