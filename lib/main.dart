import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'models/dns_server.dart';
import 'services/network_manager.dart';
import 'widgets/speed_gauge.dart';
import 'package:dio/dio.dart';
import 'package:dns_master_pro/widgets/status_header.dart';
import 'package:dns_master_pro/widgets/test_button.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dns_master_pro/services/translation_service.dart';
import 'package:dns_master_pro/services/dns_storage_service.dart';
import 'package:dns_master_pro/screens/manage_dns_page.dart';
import 'package:provider/provider.dart';
import 'services/theme_manager.dart';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';
import 'package:audioplayers/audioplayers.dart';



void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const DNSMasterPro(),
    ),
  );
}


// --- SplashScreen ---
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  double _opacity = 0.0;

  @override
  void initState() {
    super.initState();
    _requestNotificationPermission();
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _opacity = 1.0);
    });

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const DNSHomePage(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 800),
          ),
        );
      }
    });
  }

  Future<void> _requestNotificationPermission() async {
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      if (androidInfo.version.sdkInt >= 33) { // اندروید ۱۳ و بالاتر
        debugPrint("لطفاً اجازه نوتفیکیشن را در تنظیمات چک کنید");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F111A),
      body: AnimatedOpacity(
        duration: const Duration(seconds: 1),
        opacity: _opacity,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.8, end: 1.0),
                duration: const Duration(seconds: 2),
                curve: Curves.elasticOut,
                builder: (context, val, child) {
                  return Transform.scale(
                    scale: val,
                    child: Container(
                      padding: const EdgeInsets.all(25),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.cyanAccent.withOpacity(0.15 * val),
                            blurRadius: 50,
                            spreadRadius: 15,
                          )
                        ],
                      ),
                      child: const Icon(Icons.bolt_rounded, size: 90, color: Colors.cyanAccent),
                    ),
                  );
                },
              ),
              const SizedBox(height: 30),
              const Text(
                "DNS MASTER PRO",
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 4, color: Colors.white),
              ),
              const SizedBox(height: 60),
              const CircularProgressIndicator(color: Colors.cyanAccent, strokeWidth: 2),
            ],
          ),
        ),
      ),
    );
  }
}

class DNSMasterPro extends StatelessWidget {
  const DNSMasterPro({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: themeProvider.lightTheme,
      darkTheme: themeProvider.darkTheme,
      themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: const SplashScreen(),
    );
  }
}

// --- HomePage ---
class DNSHomePage extends StatefulWidget {
  const DNSHomePage({super.key});
  @override
  State<DNSHomePage> createState() => _DNSHomePageState();
}

class _DNSHomePageState extends State<DNSHomePage> with WidgetsBindingObserver{
  Timer? _networkCheckerTimer;

  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;

  static const platform = MethodChannel('com.mory65.dnsmasterpro/vpn');
  String selectedCategory = "All";
  List<String> categories = ["All", "General", "Gaming", "Security", "Family", "Private"];

  String currentLang = 'en';
  List<DnsServer> displayServers = [];
  String? selectedDns;
  bool isConnected = false;
  bool isConnecting = false;
  bool isTestingNetwork = false;

  Map<String, int?> serverPings = {};
  double downloadSpeed = 0.0;
  double uploadSpeed = 0.0;

  String t(String key) => TranslationService.t(currentLang, key);
  StreamSubscription<List<ConnectivityResult>>? connectivitySubscription;


  final AudioPlayer _audioPlayer = AudioPlayer();

  Future<void> _playConnectSound() async {
    try {
      await _audioPlayer.play(AssetSource('sounds/connect.mp3'), volume: 1.0);
    } catch (e) {
      debugPrint("خطا در پخش صدا: $e");
    }
  }


  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed) {
      // کاربر برگشت به برنامه: تایمر رو مجدد استارت بزن و وضعیت رو سینک کن
      _startNetworkTimer();
      _handleSyncAll();
      debugPrint("تایمر فعال شد (برنامه در پیش‌زمینه)");
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      // کاربر از برنامه خارج شد: تایمر رو متوقف کن تا باتری مصرف نشه
      _networkCheckerTimer?.cancel();
      debugPrint("تایمر متوقف شد (برنامه در پس‌زمینه)");
    }
  }


  void _startNetworkTimer() {
    _networkCheckerTimer?.cancel(); // اگر تایمر قبلی باز مانده، ببندش

    _networkCheckerTimer = Timer.periodic(const Duration(seconds: 4), (timer) async {
      if (isConnected && !isConnecting) {
        try {
          final bool isStillRunning = await platform.invokeMethod('isVpnActive');

          var connectivityResult = await (Connectivity().checkConnectivity());
          bool hasNoInternet = connectivityResult.contains(ConnectivityResult.none);

          if (!isStillRunning || hasNoInternet) {
            debugPrint("قطع سرویس یا اینترنت شناسایی شد. ریست UI...");
            _forceStopVpn();
          }
        } catch (e) {
          debugPrint("خطا در تایمر: $e");
        }
      }
    });
  }



  Future<void> testStorage() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('test_key', 'Hello Morteza');
    String? value = prefs.getString('test_key');
    debugPrint("تست حافظه: $value");
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _startNetworkTimer();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestNotificationPermission();
    });

    _loadAllData();
    _handleSyncAll();
  }


  Future<void> _requestNotificationPermission() async {
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;

      if (androidInfo.version.sdkInt >= 33) {
        var status = await Permission.notification.status;

        if (status.isDenied) {
          // درخواست اول یا دوم
          await Permission.notification.request();
        } else if (status.isPermanentlyDenied) {

          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text("اجازه نوتفیکیشن", style: TextStyle(fontFamily: 'Vazir')),
              content: const Text(
                  "برای نمایش وضعیت اتصال در نوار اعلان، لطفاً در صفحه تنظیمات، گزینه Notifications را فعال کنید.",
                  style: TextStyle(fontFamily: 'Vazir')
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("انصراف"),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    openAppSettings(); // باز کردن تنظیمات گوشی
                  },
                  child: const Text("تنظیمات"),
                ),
              ],
            ),
          );
        }
      }
    }
  }


  @override
  void dispose() {

    _networkCheckerTimer?.cancel();


    _connectivitySubscription.cancel();


    _audioPlayer.dispose();

    WidgetsBinding.instance.removeObserver(this);

    super.dispose();
  }


  Future<void> _handleSyncAll() async {
    try {
      final bool isVpnActive = await platform.invokeMethod('isVpnActive');
      final prefs = await SharedPreferences.getInstance();

      if (mounted) {
        setState(() {
          isConnected = isVpnActive;

          if (isVpnActive) {

            selectedDns = prefs.getString('selectedDns');
          } else {

            selectedDns = null;
            if (!isConnecting) {

              prefs.remove('selectedDns');
            }
          }
        });
      }
    } catch (e) {
      debugPrint("Sync Error: $e");
    }
  }

  Future<void> _loadAllData() async {
    await _loadSettings();
    final servers = await DnsStorageService.getAllServers();
    setState(() => displayServers = servers);
    _updateAllPings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      currentLang = prefs.getString('lang') ?? 'en';
      selectedDns = prefs.getString('selectedDns');
    });
  }

  Future<void> _updateLanguage(String newLang) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lang', newLang);
    setState(() => currentLang = newLang);
  }

  Future<void> _updateAllPings() async {
    for (var server in displayServers) {
      try {
        final p = await NetworkManager.getPing(server.dns).timeout(const Duration(seconds: 2));
        if (mounted) setState(() => serverPings[server.dns] = p);
      } catch (_) {
        if (mounted) setState(() => serverPings[server.dns] = null);
      }
    }
  }


  Future<void> _handleFullSpeedTest() async {
    if (isTestingNetwork) return;


    var connectivityResult = await (Connectivity().checkConnectivity());
    if (connectivityResult.contains(ConnectivityResult.none)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              currentLang == 'fa'
                  ? "ابتدا اینترنت گوشی خود را وصل کنید!"
                  : "Please turn on your internet connection first!",
              style: const TextStyle(fontFamily: 'Vazir', fontSize: 14),
            ),
            backgroundColor: Colors.orangeAccent,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    setState(() {
      isTestingNetwork = true;
      downloadSpeed = 0.0;
      uploadSpeed = 0.0;
    });

    try {
      await _updateAllPings();
      await _runActualSpeedTest().timeout(const Duration(seconds: 25));

    } catch (e) {
      debugPrint("Full Test Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              currentLang == 'fa'
                  ? "اختلال در شبکه حین تست! لطفاً اتصال را بررسی کنید."
                  : "Network error during test! Please check your connection.",
              style: const TextStyle(fontFamily: 'Vazir', fontSize: 14),
            ),
            backgroundColor: Colors.redAccent, // رنگ قرمز برای خطای حین اجرا
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => isTestingNetwork = false);
    }
  }

  Future<void> _runActualSpeedTest() async {
    setState(() {
      downloadSpeed = 0.0;
      uploadSpeed = 0.0;
      isTestingNetwork = true;
    });

    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 15);

    try {

      final dnRequest = await client.getUrl(Uri.parse("http://cachefly.cachefly.net/100mb.test"));
      dnRequest.headers.add("Range", "bytes=0-5242880"); // ۵ مگابایت اول
      final dnResponse = await dnRequest.close();

      if (dnResponse.statusCode == 200 || dnResponse.statusCode == 206) {
        final startTime = DateTime.now();
        int receivedBytes = 0;
        await for (var data in dnResponse) {
          receivedBytes += data.length;
          final elapsed = DateTime.now().difference(startTime).inMilliseconds / 1000;
          if (elapsed > 0.1 && mounted) {
            setState(() {
              double currentSpeed = (receivedBytes * 8 / (1024 * 1024)) / elapsed;
              downloadSpeed = (downloadSpeed * 0.2) + (currentSpeed * 0.8);
            });
          }
        }
      }

      await Future.delayed(const Duration(milliseconds: 500));

      final List<int> randomData = List.generate(512 * 1024, (i) => i % 256); // ۵۱۲ کیلوبایت کافیست
      final upStartTime = DateTime.now();

      final upRequest = await client.postUrl(Uri.parse("https://httpbin.org/post"));
      upRequest.headers.set("Content-Type", "application/octet-stream");

      upRequest.add(randomData);
      await upRequest.flush();
      final upResponse = await upRequest.close().timeout(const Duration(seconds: 15));

      if (upResponse.statusCode == 200) {
        final elapsed = DateTime.now().difference(upStartTime).inMilliseconds / 1000;
        setState(() {
          uploadSpeed = (randomData.length * 8 / (1024 * 1024)) / elapsed;
        });
      }


      debugPrint("آپلود تمام شد با کد: ${upResponse.statusCode}");

    } catch (e) {
      debugPrint("خطای کلی در تست: $e");
    } finally {
      client.close();
      if (mounted) setState(() => isTestingNetwork = false);
    }
  }

  Future<void> _toggleVpn(String dns) async {
    if (isConnecting) return;


    var connectivityResult = await (Connectivity().checkConnectivity());
    if (connectivityResult.contains(ConnectivityResult.none)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              currentLang == 'fa' ? "ابتدا اینترنت را وصل کنید!" : "Please connect to internet first!",
              style: const TextStyle(fontFamily: 'Vazir'),
            ),
            backgroundColor: Colors.orangeAccent,
          ),
        );
      }
      return;
    }

    setState(() {
      isConnecting = true;
      selectedDns = dns;
      isConnected = false;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selectedDns', dns);

      await platform.invokeMethod('applyDNS', {"dns": dns});

      await Future.delayed(const Duration(seconds: 5));

      final bool check = await platform.invokeMethod('isVpnActive');
      if (check) {
        _playConnectSound();
      }

    } catch (e) {
      debugPrint("Toggle Error: $e");
    } finally {
      if (mounted) {

        await _handleSyncAll();
        setState(() => isConnecting = false);
      }
    }
  }

  Future<void> _forceStopVpn() async {
    if (!mounted) return;

    try {

      await platform.invokeMethod('stopDNS');

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('selectedDns');

      setState(() {
        isConnected = false;
        selectedDns = null;
        isConnecting = false;
      });


      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            currentLang == 'fa' ? "اتصال قطع شد (اینترنت در دسترس نیست)" : "Disconnected (No Internet)",
            style: const TextStyle(fontFamily: 'Vazir'),
          ),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      debugPrint("Force stop failed: $e");
    }
  }


  Future<void> _stopVpn() async {
    // ۱. بلافاصله وضعیت در حال تغییر را نشان بده
    setState(() => isConnecting = true);

    try {


      await platform.invokeMethod('stopDNS').timeout(
        const Duration(seconds: 1),
        onTimeout: () {
          debugPrint("زمان پاسخ جاوا به پایان رسید - احتمالا سرویس قبلا توسط سیستم بسته شده");
          return null; // ادامه عملیات بدون توجه به پاسخ جاوا
        },
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('selectedDns');

      await Future.delayed(const Duration(milliseconds: 500));

    } catch (e) {
      debugPrint("خطا در فرآیند توقف: $e");
    } finally {
      if (mounted) {

        await _handleSyncAll();
        setState(() => isConnecting = false);
      }
    }
  }

  // --- UI Helper Methods ---
  String _getCategoryLabel(String categoryId) {
    final List<Map<String, String>> categoriesList = [
      {'id': 'General', 'en': 'General', 'fa': 'عمومی'},
      {'id': 'Gaming', 'en': 'Gaming', 'fa': 'گیمینگ'},
      {'id': 'Security', 'en': 'Security', 'fa': 'امنیت'},
      {'id': 'Family', 'en': 'Family', 'fa': 'خانواده'},
      {'id': 'Private', 'en': 'Private', 'fa': 'شخصی'},
    ];
    final cat = categoriesList.firstWhere((e) => e['id'] == categoryId, orElse: () => categoriesList[0]);
    return currentLang == 'fa' ? cat['fa']! : cat['en']!;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    List<DnsServer> filteredList = selectedCategory == "All"
        ? displayServers
        : displayServers.where((s) => s.category == selectedCategory).toList();
    //print("UI STATUS: isConnected=$isConnected, dns=$selectedDns");
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isDark ? Colors.cyanAccent.withOpacity(0.1) : Colors.blueAccent.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.bolt_rounded, color: isDark ? Colors.cyanAccent : Colors.blueAccent, size: 20),
            ),
            const SizedBox(width: 8),
            Text("DNS MASTER", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Theme.of(context).textTheme.bodyLarge?.color)),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.info_outline_rounded), onPressed: _showInfoSheet),
          IconButton(
            icon: Icon(isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
            onPressed: () => Provider.of<ThemeProvider>(context, listen: false).toggleTheme(),
          ),
          TextButton(
            onPressed: () => _updateLanguage(currentLang == 'en' ? 'fa' : 'en'),
            child: Text(currentLang == 'en' ? "FA" : "EN", style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold)),
          ),
          IconButton(
            icon: const Icon(Icons.grid_view_rounded, size: 26),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ManageDnsPage(lang: currentLang))).then((_) => _loadAllData()),
          ),
        ],
      ),
      body: Column(
        children: [
          StatusHeader(isConnected: isConnected, isConnecting: isConnecting, onDisconnect: _stopVpn, lang: currentLang),
          _buildCategoryFilter(),
          Expanded(child: _buildServerList(filteredList)),
          _buildNetworkStats(),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SpeedTestButton(isTesting: isTestingNetwork, onPressed: _handleFullSpeedTest, lang: currentLang),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilter() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: categories.map((cat) {
          bool isSelected = selectedCategory == cat;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(cat),
              selected: isSelected,
              onSelected: (v) => setState(() => selectedCategory = cat),
              selectedColor: Colors.cyanAccent.withOpacity(0.2),
              checkmarkColor: Colors.cyanAccent,
              backgroundColor: Theme.of(context).cardColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildServerList(List<DnsServer> list) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final server = list[index];
        final ping = serverPings[server.dns];
        final isCurrent = selectedDns == server.dns;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: isCurrent
                ? Colors.cyanAccent.withOpacity(0.05)
                : const Color(0xFF1C1F2E),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isCurrent ? Colors.cyanAccent : Colors.white.withOpacity(0.05),
              width: isCurrent ? 1.5 : 1,
            ),
          ),
          child: ListTile(
            leading: Icon(
                DnsServer.getCategoryIcon(server.category),
                color: isCurrent ? Colors.cyanAccent : Colors.white70
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    server.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.cyanAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _getCategoryLabel(server.category),
                    style: const TextStyle(color: Colors.cyanAccent, fontSize: 10),
                  ),
                ),
              ],
            ),
            subtitle: Text(
                server.dns,
                style: const TextStyle(color: Colors.white30, fontSize: 12),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                    ping != null ? "$ping ms" : "--",
                    style: TextStyle(
                        color: _getPingColor(ping),
                        fontWeight: FontWeight.bold,
                        fontSize: 14
                    )
                ),
                if (isCurrent)
                  const Icon(Icons.check_circle, color: Colors.cyanAccent, size: 16),
              ],
            ),
            onTap: () => _toggleVpn(server.dns),
          ),
        );
      },
    );
  }

  Widget _buildNetworkStats() => Container(
    padding: const EdgeInsets.symmetric(vertical: 20),
    margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
    decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(24)),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        SpeedGauge(title: t('download'), value: downloadSpeed, color: Colors.cyanAccent),
        Container(width: 1, height: 40, color: Colors.white10),
        SpeedGauge(title: t('upload'), value: uploadSpeed, color: Colors.pinkAccent),
      ],
    ),
  );


  void _showInfoSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1C1F2E),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, controller) => SingleChildScrollView(
          controller: controller,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                  child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),
              Text(currentLang == 'fa' ? "درباره برنامه" : "About App",
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.cyanAccent)),
              const SizedBox(height: 20),
              _buildInfoSection(
                  currentLang == 'fa' ? "DNS چیست؟" : "What is DNS?",
                  currentLang == 'fa'
                      ? "سامانه نام دامنه (DNS) مانند دفترچه تلفن اینترنت است که اسامی سایت‌ها را به اعداد (IP) تبدیل می‌کند. استفاده از DNS مناسب باعث افزایش سرعت و امنیت می‌شود."
                      : "DNS is like the internet's phonebook. Using a good DNS can improve your speed and security.",
                  Icons.help_outline_rounded),

              _buildInfoSection(
                  currentLang == 'fa' ? "سازندگان" : "Developers",
                  "Morteza & Gemini AI",
                  Icons.code_rounded),
              _buildInfoSection(
                  currentLang == 'fa' ? "نسخه برنامه" : "App Version",
                  "1.0.0 Pro",
                  Icons.info_outline_rounded),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildInfoSection(String title, String desc, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.cyanAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.cyanAccent, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.white)),
                const SizedBox(height: 4),
                Text(desc,
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 14, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
  Color _getPingColor(int? ping) {
    if (ping == null) return Colors.white24;
    if (ping < 80) return Colors.cyanAccent;
    if (ping < 150) return Colors.orangeAccent;
    return Colors.redAccent;
  }
}