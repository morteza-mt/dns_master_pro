import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class NetworkManager {
  static const platform = MethodChannel('com.example.dns/manager');

  static Future<void> startVpn(String dns) async {
    try {
      await platform.invokeMethod('applyDNS', {"dns": dns});
    } on PlatformException catch (e) {
      debugPrint("Failed to start VPN: ${e.message}");
    }
  }


  static Future<void> stopVpn() async {
    try {
      await platform.invokeMethod('stopDNS');
    } on PlatformException catch (e) {
      debugPrint("Failed to stop VPN: ${e.message}");
    }
  }

  static Future<bool> isVpnConnected() async {
    try {
      final bool connected = await platform.invokeMethod('isVpnConnected');
      return connected;
    } catch (e) {
      debugPrint("Error checking VPN status: $e");
      return false;
    }
  }


  static Future<int?> getPing(String ip) async {
    try {
      final address = InternetAddress(ip);
      final stopwatch = Stopwatch()..start();


      final socket = await Socket.connect(
          address,
          53,
          timeout: const Duration(milliseconds: 1200)
      );

      stopwatch.stop();
      await socket.close();

      return stopwatch.elapsedMilliseconds;
    } catch (e) {

      return null;
    }
  }


  static Dio getDioClient() {
    final dio = Dio();
    (dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
      final client = HttpClient();
      client.badCertificateCallback = (cert, host, port) => true;
      return client;
    };
    return dio;
  }
}