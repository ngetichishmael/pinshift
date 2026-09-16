import 'dart:convert';

import 'package:pinshift/core/geo_pin.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _pinKey = 'pinshift.last_pin';
const _jitterKey = 'pinshift.jitter_meters';
const _accuracyKey = 'pinshift.accuracy_meters';
const _lastUrlKey = 'pinshift.browser.last_url';
const _chromeUaKey = 'pinshift.browser.chrome_ua';
const _spoofHardeningKey = 'pinshift.spoof_hardening';

class PinStore {
  Future<GeoPin?> loadPin() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_pinKey);
    if (raw == null) {
      return null;
    }
    try {
      return GeoPin.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> savePin(GeoPin pin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pinKey, jsonEncode(pin.toJson()));
  }

  Future<double> loadJitter({double fallback = 4}) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_jitterKey) ?? fallback;
  }

  Future<void> saveJitter(double meters) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_jitterKey, meters);
  }

  Future<double> loadAccuracy({double fallback = 5}) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_accuracyKey) ?? fallback;
  }

  Future<void> saveAccuracy(double meters) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_accuracyKey, meters);
  }

  Future<String?> loadLastBrowserUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastUrlKey);
  }

  Future<void> saveLastBrowserUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastUrlKey, url);
  }

  Future<bool> loadChromeUserAgent() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_chromeUaKey) ?? false;
  }

  Future<void> saveChromeUserAgent(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_chromeUaKey, enabled);
  }

  Future<bool> loadSpoofHardening() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_spoofHardeningKey) ?? false;
  }

  Future<void> saveSpoofHardening(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_spoofHardeningKey, enabled);
  }
}
