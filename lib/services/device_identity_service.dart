import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Stable app installation identity for anti-proxy / backend validation.
/// Uses the same preference key as [BleService] for UUID so BLE registration
/// and secure login stay aligned.
class DeviceIdentity {
  const DeviceIdentity({
    required this.deviceUuid,
    required this.deviceName,
    required this.deviceFingerprint,
  });

  final String deviceUuid;
  final String deviceName;
  final String deviceFingerprint;
}

class DeviceIdentityService {
  DeviceIdentityService._();
  static final DeviceIdentityService _i = DeviceIdentityService._();
  factory DeviceIdentityService() => _i;

  static const _storageKey = 'attendance_device_uuid';
  static final Uuid _uuidGen = Uuid();

  static const FlutterSecureStorage _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  DeviceIdentity? _cache;

  Future<DeviceIdentity> getDeviceIdentity() async {
    if (_cache != null) return _cache!;
    final uuid = await getOrCreateDeviceUuid();
    final name = await getDeviceName();
    final fp = await getDeviceFingerprint();
    _cache = DeviceIdentity(
      deviceUuid: uuid,
      deviceName: name,
      deviceFingerprint: fp,
    );
    return _cache!;
  }

  void clearCache() {
    _cache = null;
  }

  Future<String> getOrCreateDeviceUuid() async {
    final fromSecure = (await _secure.read(key: _storageKey))?.trim();
    if (fromSecure != null && fromSecure.isNotEmpty) {
      await _mirrorUuidToPrefs(fromSecure);
      return fromSecure;
    }

    final prefs = await SharedPreferences.getInstance();
    final fromPrefs = prefs.getString(_storageKey)?.trim();
    if (fromPrefs != null && fromPrefs.isNotEmpty) {
      await _secure.write(key: _storageKey, value: fromPrefs);
      return fromPrefs;
    }

    final generated = _uuidGen.v4();
    await _secure.write(key: _storageKey, value: generated);
    await prefs.setString(_storageKey, generated);
    return generated;
  }

  Future<void> _mirrorUuidToPrefs(String uuid) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_storageKey)?.trim();
    if (existing != uuid) {
      await prefs.setString(_storageKey, uuid);
    }
  }

  Future<String> getDeviceName() async {
    if (kIsWeb) return 'Web';

    final plugin = DeviceInfoPlugin();
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        final a = await plugin.androidInfo;
        final model = a.model.trim().isEmpty ? 'Android' : a.model.trim();
        final mfr = a.manufacturer.trim();
        return mfr.isEmpty ? model : '$mfr $model';
      case TargetPlatform.iOS:
        final i = await plugin.iosInfo;
        final machine = i.utsname.machine.trim();
        final name = i.name.trim();
        if (name.isNotEmpty) return name;
        return machine.isEmpty ? 'iOS' : machine;
      default:
        final di = await plugin.deviceInfo;
        final data = di.data;
        return (data['model'] ?? data['machine'] ?? 'Device').toString();
    }
  }

  Future<String> getDeviceFingerprint() async {
    final id = await getOrCreateDeviceUuid();
    final raw = StringBuffer()
      ..write(id)
      ..write('|')
      ..write(defaultTargetPlatform.name);

    if (kIsWeb) {
      raw.write('|web');
    } else {
      final plugin = DeviceInfoPlugin();
      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
          final a = await plugin.androidInfo;
          raw
            ..write('|android|')
            ..write(a.manufacturer)
            ..write('|')
            ..write(a.model)
            ..write('|')
            ..write(a.version.release);
        case TargetPlatform.iOS:
          final i = await plugin.iosInfo;
          raw
            ..write('|ios|')
            ..write(i.name)
            ..write('|')
            ..write(i.model)
            ..write('|')
            ..write(i.systemVersion);
        default:
          final di = await plugin.deviceInfo;
          raw.write('|${jsonEncode(di.data)}');
      }
    }

    final bytes = utf8.encode(raw.toString());
    return sha256.convert(bytes).toString();
  }
}
