import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/router_models.dart';

class ProfileStorageService {
  static const _profilesKey = 'saved_router_profiles_v1';
  static const _activeProfileIdKey = 'active_router_profile_id_v1';

  Future<List<RouterProfile>> getProfiles() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_profilesKey);
    if (raw == null || raw.isEmpty) return [];

    final List<dynamic> decoded = jsonDecode(raw);
    return decoded
        .map((e) => RouterProfile.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> saveProfile(RouterProfile profile, {bool setAsActive = true}) async {
    final prefs = await SharedPreferences.getInstance();
    final profiles = await getProfiles();

    final existingIdx = profiles.indexWhere((p) => p.id == profile.id);
    if (existingIdx >= 0) {
      profiles[existingIdx] = profile;
    } else {
      profiles.add(profile);
    }

    await prefs.setString(
      _profilesKey,
      jsonEncode(profiles.map((p) => p.toJson()).toList()),
    );

    if (setAsActive) {
      await prefs.setString(_activeProfileIdKey, profile.id);
    }
  }

  Future<void> deleteProfile(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final profiles = await getProfiles();
    profiles.removeWhere((p) => p.id == id);

    await prefs.setString(
      _profilesKey,
      jsonEncode(profiles.map((p) => p.toJson()).toList()),
    );

    final activeId = prefs.getString(_activeProfileIdKey);
    if (activeId == id) {
      await prefs.remove(_activeProfileIdKey);
    }
  }

  Future<void> setActiveProfileId(String? id) async {
    final prefs = await SharedPreferences.getInstance();
    if (id == null) {
      await prefs.remove(_activeProfileIdKey);
    } else {
      await prefs.setString(_activeProfileIdKey, id);
    }
  }

  Future<RouterProfile?> getActiveProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final activeId = prefs.getString(_activeProfileIdKey);
    if (activeId == null) return null;

    final profiles = await getProfiles();
    try {
      return profiles.firstWhere((p) => p.id == activeId);
    } catch (_) {
      return null;
    }
  }
}