import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'apk_scanner_service.dart';
import 'radar_scanner.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DarvozaApp());
}

class DarvozaApp extends StatefulWidget {
  const DarvozaApp({super.key});

  @override
  State<DarvozaApp> createState() => _DarvozaAppState();
}

class _DarvozaAppState extends State<DarvozaApp> {
  String _currentLanguage = "uz"; // "uz", "ru", "en"
  bool _hapticEnabled = true;

  void _changeLanguage(String lang) {
    setState(() {
      _currentLanguage = lang;
    });
  }

  void _toggleHaptic(bool val) {
    setState(() {
      _hapticEnabled = val;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Darvoza Security',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF090D16),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00FF88),
          surface: Color(0xFF111726),
          error: Color(0xFFFF2E63),
        ),
      ),
      home: DarvozaMainScreen(
        language: _currentLanguage,
        hapticEnabled: _hapticEnabled,
        onLanguageChanged: _changeLanguage,
        onHapticToggled: _toggleHaptic,
      ),
    );
  }
}

class DarvozaMainScreen extends StatefulWidget {
  final String language;
  final bool hapticEnabled;
  final Function(String) onLanguageChanged;
  final Function(bool) onHapticToggled;

  const DarvozaMainScreen({
    super.key,
    required this.language,
    required this.hapticEnabled,
    required this.onLanguageChanged,
    required this.onHapticToggled,
  });

  @override
  State<DarvozaMainScreen> createState() => _DarvozaMainScreenState();
}

class _DarvozaMainScreenState extends State<DarvozaMainScreen> {
  static const MethodChannel _platform =
      MethodChannel('com.darvoza.security/apk_receiver');

  int _selectedTab = 0; // 0: Himoya (Asosiy), 1: Xavfsizlik bo'yicha maslahatlar, 2: Sozlamalar
  bool _isScanning = false;
  double _scanProgress = 0.0;
  String _scanStatusText = "FAYL TAHLIL QILINMOQDA...";
  ApkAnalysisResult? _analysisResult;
  bool _autoGuardActive = true;

  // Ko'p tilli lug'at (Localization)
  Map<String, Map<String, String>> get _strings => {
        "uz": {
          "appName": "DARVOZA",
          "subtitle": "XAVFSIZLIK QALQONI",
          "active": "FAOL",
          "inactive": "O'CHIRILGAN",
          "tabGuard": "Himoya",
          "tabTips": "Maslahatlar",
          "tabSettings": "Sozlamalar",
          "autoGuardTitle": "Avtomatik himoya yoqilgan",
          "autoGuardDesc":
              "Telegram, brauzer yoki fayllardan yangi APK ochilganda avtomatik tekshiruv boshlanadi.",
          "btnScan": "Faylni tanlash va tekshirish",
          "offlineTitle": "100% Qurilmada",
          "offlineDesc": "Internet talab qilinmaydi",
          "shaTitle": "Raqamli imzo",
          "shaDesc": "Soxta ilovalarni aniqlash",
          "settingsTitle": "Sozlamalar",
          "langTitle": "Ilova tili",
          "hapticTitle": "Tugma bosilganda tebranish",
          "privacyTitle": "Maxfiylik kafolati",
          "privacyDesc":
              "Darvoza ilovasi shaxsiy ma'lumotlaringizni yig'maydi va serverga jo'natmaydi.",
          "appVersion": "Dastur versiyasi",
          "tipsTitle": "Xavfsizlik bo'yicha muhim eslatmalar",
          "tip1Title": "SMS o'qish ruxsati",
          "tip1Desc":
              "Agar oddiy o'yin yoki kalkulyator SMS o'qishni so'rasa, bu bank kodlarini o'g'irlash uchun bo'lishi mumkin.",
          "tip2Title": "Maxsus imkoniyatlar (Accessibility)",
          "tip2Desc":
              "Bu ruxsat ilovaga ekranda yozgan parollaringizni ko'rish imkonini beradi. Buni faqat ishonchli dasturlarga bering.",
          "tip3Title": "Soxta yangilanishlar",
          "tip3Desc":
              "Telegram kanallardan yuklangan noma'lum APK fayllarni o'rnatishdan oldin doimo Darvoza orqali tekshiring.",
        },
        "ru": {
          "appName": "DARVOZA",
          "subtitle": "КИБЕР-ЩИТ",
          "active": "АКТИВЕН",
          "inactive": "ОТКЛЮЧЕН",
          "tabGuard": "Защита",
          "tabTips": "Советы",
          "tabSettings": "Настройки",
          "autoGuardTitle": "Автозащита включена",
          "autoGuardDesc":
              "При открытии любого APK из Telegram или браузера он автоматически проверяется перед установкой.",
          "btnScan": "Выбрать APK и проверить",
          "offlineTitle": "100% Локально",
          "offlineDesc": "Работает без интернета",
          "shaTitle": "Цифровая подпись",
          "shaDesc": "Поиск поддельных APK",
          "settingsTitle": "Настройки",
          "langTitle": "Язык приложения",
          "hapticTitle": "Вибрация при нажатии",
          "privacyTitle": "Политика конфиденциальности",
          "privacyDesc":
              "Darvoza не собирает и не отправляет ваши личные данные на сторонние серверы.",
          "appVersion": "Версия приложения",
          "tipsTitle": "Правила безопасности",
          "tip1Title": "Доступ к SMS",
          "tip1Desc":
              "Если игра или утилита просит читать SMS — это угроза кражи банковских кодов.",
          "tip2Title": "Специальные возможности",
          "tip2Desc":
              "Дает приложению право считывать нажатия клавиш и пароли. Будьте предельно осторожны.",
          "tip3Title": "Сторонние APK",
          "tip3Desc":
              "Всегда проверяйте файлы из Telegram и неизвестных сайтов перед установкой.",
        },
        "en": {
          "appName": "DARVOZA",
          "subtitle": "CYBER SHIELD",
          "active": "ACTIVE",
          "inactive": "DISABLED",
          "tabGuard": "Guard",
          "tabTips": "Tips",
          "tabSettings": "Settings",
          "autoGuardTitle": "Auto-Guard is Active",
          "autoGuardDesc":
              "Any incoming APK from Telegram or browsers will be intercepted and scanned before installation.",
          "btnScan": "Select & Scan APK File",
          "offlineTitle": "100% On-Device",
          "offlineDesc": "No internet connection needed",
          "shaTitle": "Digital Signature",
          "shaDesc": "Detect fake & modified apps",
          "settingsTitle": "Settings",
          "langTitle": "App Language",
          "hapticTitle": "Haptic Feedback",
          "privacyTitle": "Privacy Assurance",
          "privacyDesc":
              "Darvoza runs completely offline and never uploads your private files or analytics.",
          "appVersion": "App Version",
          "tipsTitle": "Security Best Practices",
          "tip1Title": "SMS Read Permissions",
          "tip1Desc":
              "If a casual game or utility requests SMS reading, it might be designed to steal banking OTPs.",
          "tip2Title": "Accessibility Services",
          "tip2Desc":
              "Allows full keystroke logging and screen monitoring. Grant this only to strictly trusted apps.",
          "tip3Title": "Third-Party APKs",
          "tip3Desc":
              "Always inspect APK files downloaded from messenger channels before opening them.",
        },
      };

  String _t(String key) {
    return _strings[widget.language]?[key] ?? _strings["uz"]![key] ?? key;
  }

  void _triggerHaptic(HapticFeedbackType type) {
    if (!widget.hapticEnabled) return;
    switch (type) {
      case HapticFeedbackType.selection:
        HapticFeedback.selectionClick();
        break;
      case HapticFeedbackType.medium:
        HapticFeedback.mediumImpact();
        break;
      case HapticFeedbackType.heavy:
        HapticFeedback.heavyImpact();
        break;
    }
  }

  @override
  void initState() {
    super.initState();
    _initNativeReceiver();
  }

  void _initNativeReceiver() {
    _platform.invokeMethod<String>('getInitialApk').then((path) {
      if (path != null && path.isNotEmpty) {
        _runComprehensiveScan(path);
      }
    });

    _platform.setMethodCallHandler((call) async {
      if (call.method == 'onApkReceived') {
        final path = call.arguments as String?;
        if (path != null && path.isNotEmpty) {
          _runComprehensiveScan(path);
        }
      }
    });
  }

  Future<void> _runComprehensiveScan(String filePath) async {
    _triggerHaptic(HapticFeedbackType.medium);
    setState(() {
      _isScanning = true;
      _analysisResult = null;
      _scanProgress = 0.20;
      _scanStatusText = "Fayl ochilmoqda...";
    });

    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    setState(() {
      _scanProgress = 0.60;
      _scanStatusText = "Ruxsatlar va imzolar tekshirilmoqda...";
    });

    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() {
      _scanProgress = 0.90;
      _scanStatusText = "Xavfsizlik darajasi baholanmoqda...";
    });

    try {
      final result = await ApkScannerService.analyzeApk(filePath);
      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;

      setState(() {
        _scanProgress = 1.0;
        _isScanning = false;
        _analysisResult = result;
      });

      if (result.isSafe) {
        _triggerHaptic(HapticFeedbackType.selection);
      } else {
        _triggerHaptic(HapticFeedbackType.heavy);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isScanning = false;
        _analysisResult = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFFF2E63),
          content: Text("Xatolik: $e"),
        ),
      );
    }
  }

  Future<void> _pickFileManually() async {
    _triggerHaptic(HapticFeedbackType.selection);
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['apk'],
    );

    if (files.isNotEmpty && files.first.path != null) {
      _runComprehensiveScan(files.first.path!);
    }
  }

  Future<void> _installApk(String path) async {
    _triggerHaptic(HapticFeedbackType.selection);
    try {
      await _platform.invokeMethod('installApk', {'path': path});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("O'rnatishda xatolik: $e")),
        );
      }
    }
  }

  Future<void> _deleteDangerousApk(String path) async {
    _triggerHaptic(HapticFeedbackType.heavy);
    try {
      final res = await _platform.invokeMethod<bool>('deleteApk', {'path': path});
      if (res == true && mounted) {
        setState(() {
          _analysisResult = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF00FF88),
            content: Text("Fayl muvaffaqiyatli o'chirildi!"),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("O'chirishda xatolik: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0A0E17),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildCleanHeader(),
              Expanded(
                child: _isScanning
                    ? _buildScanningHud()
                    : _analysisResult != null
                        ? _buildDetailedThreatReport(_analysisResult!)
                        : _buildTabContent(),
              ),
              if (!_isScanning && _analysisResult == null) _buildCleanBottomNav(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCleanHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        color: Color(0xFF101624),
        border: Border(
          bottom: BorderSide(color: Color(0xFF1E2638), width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.asset(
                  'assets/images/darvoza_logo.png',
                  width: 36,
                  height: 36,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFF00FF88).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.shield, color: Color(0xFF00FF88), size: 22),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _t("appName"),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    _t("subtitle"),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: Color(0xFF00FF88),
                    ),
                  ),
                ],
              ),
            ],
          ),
          // Faollik holati (Bosilganda almashtirish imkoniyati bilan)
          GestureDetector(
            onTap: () {
              _triggerHaptic(HapticFeedbackType.selection);
              setState(() {
                _autoGuardActive = !_autoGuardActive;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _autoGuardActive
                    ? const Color(0xFF00FF88).withValues(alpha: 0.12)
                    : Colors.white10,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _autoGuardActive
                      ? const Color(0xFF00FF88).withValues(alpha: 0.5)
                      : Colors.white24,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _autoGuardActive ? const Color(0xFF00FF88) : Colors.white38,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _autoGuardActive ? _t("active") : _t("inactive"),
                    style: TextStyle(
                      color: _autoGuardActive ? const Color(0xFF00FF88) : Colors.white60,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_selectedTab) {
      case 0:
        return _buildGuardDashboard();
      case 1:
        return _buildTipsDashboard();
      case 2:
        return _buildSettingsDashboard();
      default:
        return _buildGuardDashboard();
    }
  }

  Widget _buildScanningHud() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CyberRadarWidget(
              size: 220,
              primaryColor: const Color(0xFF00FF88),
              statusText: _scanStatusText,
              progress: _scanProgress,
            ),
            const SizedBox(height: 32),
            const Text(
              "APK FAYL XAVFSIZLIGI TEKSHIRILMOQDA",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuardDashboard() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 10),
          // Markaziy Karta
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 26),
            decoration: BoxDecoration(
              color: const Color(0xFF111827),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF1F293D)),
            ),
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.asset(
                    'assets/images/darvoza_logo.png',
                    width: 100,
                    height: 100,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.shield,
                      size: 80,
                      color: Color(0xFF00FF88),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  _t("autoGuardTitle"),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _t("autoGuardDesc"),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.white60,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),

                // Qulay, to'liq sig'adigan bosh tugma
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _pickFileManually,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00FF88),
                      foregroundColor: const Color(0xFF05101E),
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.file_open_rounded, size: 20, color: Colors.black87),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            _t("btnScan"),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // 2 ta ixcham parametr kartochkasi
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111827),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF1F293D)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.lock_clock_outlined, color: Color(0xFF00FF88), size: 20),
                      const SizedBox(height: 8),
                      Text(
                        _t("offlineTitle"),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _t("offlineDesc"),
                        style: const TextStyle(fontSize: 11, color: Colors.white54),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111827),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF1F293D)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.verified_outlined, color: Color(0xFF00E5FF), size: 20),
                      const SizedBox(height: 8),
                      Text(
                        _t("shaTitle"),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _t("shaDesc"),
                        style: const TextStyle(fontSize: 11, color: Colors.white54),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Tushunarsiz "Kiber audit" o'rniga haqiqiy foydali "Xavfsizlik Maslahatlari" bo'limi
  Widget _buildTipsDashboard() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          _t("tipsTitle"),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        _buildSimpleTipCard(
          icon: Icons.sms_outlined,
          color: const Color(0xFFFF2E63),
          title: _t("tip1Title"),
          desc: _t("tip1Desc"),
        ),
        _buildSimpleTipCard(
          icon: Icons.accessibility_new_outlined,
          color: const Color(0xFFFFB800),
          title: _t("tip2Title"),
          desc: _t("tip2Desc"),
        ),
        _buildSimpleTipCard(
          icon: Icons.download_for_offline_outlined,
          color: const Color(0xFF00FF88),
          title: _t("tip3Title"),
          desc: _t("tip3Desc"),
        ),
      ],
    );
  }

  Widget _buildSimpleTipCard({
    required IconData icon,
    required Color color,
    required String title,
    required String desc,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1F293D)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  desc,
                  style: const TextStyle(fontSize: 12, color: Colors.white70, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // To'liq ishlaydigan Sozlamalar bo'limi
  Widget _buildSettingsDashboard() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          _t("settingsTitle"),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),

        // Tilni o'zgartirish tugmasi (ishlaydi)
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF111827),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF1F293D)),
          ),
          child: Row(
            children: [
              const Icon(Icons.language, color: Color(0xFF00FF88), size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  _t("langTitle"),
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ),
              DropdownButton<String>(
                value: widget.language,
                dropdownColor: const Color(0xFF111827),
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(value: "uz", child: Text("O'zbek")),
                  DropdownMenuItem(value: "ru", child: Text("Русский")),
                  DropdownMenuItem(value: "en", child: Text("English")),
                ],
                onChanged: (val) {
                  if (val != null) {
                    _triggerHaptic(HapticFeedbackType.selection);
                    widget.onLanguageChanged(val);
                  }
                },
              ),
            ],
          ),
        ),

        // Haptik tebranish (ishlaydi)
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF111827),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF1F293D)),
          ),
          child: Row(
            children: [
              const Icon(Icons.vibration, color: Color(0xFF00FF88), size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  _t("hapticTitle"),
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ),
              Switch(
                value: widget.hapticEnabled,
                activeThumbColor: const Color(0xFF00FF88),
                onChanged: (val) {
                  widget.onHapticToggled(val);
                  if (val) HapticFeedback.mediumImpact();
                },
              ),
            ],
          ),
        ),

        // Maxfiylik kafolati
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF111827),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF1F293D)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.shield_moon_outlined, color: Color(0xFF00E5FF), size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _t("privacyTitle"),
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _t("privacyDesc"),
                      style: const TextStyle(fontSize: 12, color: Colors.white54, height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Versiya
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF111827),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF1F293D)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.white60, size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  _t("appVersion"),
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ),
              const Text(
                "v2.1 Stable",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF00FF88)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Tahlil natijasi ekrani
  Widget _buildDetailedThreatReport(ApkAnalysisResult res) {
    final Color statusColor;
    final IconData statusIcon;

    switch (res.threatLevel) {
      case ThreatLevel.safe:
        statusColor = const Color(0xFF00FF88);
        statusIcon = Icons.verified_user_rounded;
        break;
      case ThreatLevel.warning:
        statusColor = const Color(0xFFFFB800);
        statusIcon = Icons.warning_amber_rounded;
        break;
      case ThreatLevel.critical:
        statusColor = const Color(0xFFFF2E63);
        statusIcon = Icons.gpp_bad_rounded;
        break;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Natija kartochkasi
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF111827),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: statusColor.withValues(alpha: 0.5), width: 1.5),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(statusIcon, color: statusColor, size: 32),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              res.summaryTitle,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                color: statusColor,
                              ),
                            ),
                            Text(
                              "${(res.fileSize / (1024 * 1024)).toStringAsFixed(1)} MB • ${res.fileName}",
                              style: const TextStyle(fontSize: 11, color: Colors.white54),
                            ),
                          ],
                        ),
                      ],
                    ),
                    // Baholash doirasi
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: statusColor.withValues(alpha: 0.15),
                        border: Border.all(color: statusColor, width: 2),
                      ),
                      child: Center(
                        child: Text(
                          "${res.securityScore}",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  res.reason,
                  style: const TextStyle(fontSize: 12, color: Colors.white70, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // SHA-256
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0D121D),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF1F293D)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "SHA-256 IMZOSI:",
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF00E5FF)),
                ),
                const SizedBox(height: 4),
                SelectableText(
                  res.sha256,
                  style: const TextStyle(fontSize: 10, color: Colors.white60, fontFamily: 'monospace'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Xavfli ruxsatlar
          if (res.dangerousPermissions.isNotEmpty) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Xavfli huquqlar (${res.dangerousPermissions.length}):",
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFFF2E63)),
              ),
            ),
            const SizedBox(height: 8),
            ...res.dangerousPermissions.map((dp) => _buildPermissionTile(dp, isCritical: true)),
            const SizedBox(height: 12),
          ],

          // Standart ruxsatlar
          if (res.normalPermissions.isNotEmpty) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Standart huquqlar (${res.normalPermissions.length}):",
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white70),
              ),
            ),
            const SizedBox(height: 8),
            ...res.normalPermissions.map((np) => _buildPermissionTile(np, isCritical: false)),
            const SizedBox(height: 18),
          ],

          // Tugmalar
          Row(
            children: [
              if (res.isSafe)
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _installApk(res.filePath),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00FF88),
                      foregroundColor: const Color(0xFF05101E),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.install_mobile, color: Colors.black87),
                    label: const Text(
                      "O'RNATISH",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                )
              else
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _deleteDangerousApk(res.filePath),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF2E63),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text(
                      "FAYLNI O'CHIRISH",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ),
              const SizedBox(width: 10),
              OutlinedButton(
                onPressed: () {
                  _triggerHaptic(HapticFeedbackType.selection);
                  setState(() {
                    _analysisResult = null;
                  });
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: const BorderSide(color: Color(0xFF1F293D)),
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text("Yopish"),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildPermissionTile(PermissionInfo p, {required bool isCritical}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isCritical ? const Color(0xFFFF2E63).withValues(alpha: 0.08) : const Color(0xFF111827),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isCritical ? const Color(0xFFFF2E63).withValues(alpha: 0.3) : const Color(0xFF1F293D),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isCritical ? Icons.error_outline : Icons.check_circle_outline,
            color: isCritical ? const Color(0xFFFF2E63) : const Color(0xFF00FF88),
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: isCritical ? const Color(0xFFFF2E63) : Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  p.description,
                  style: const TextStyle(fontSize: 11, color: Colors.white60),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCleanBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF101624),
        border: Border(top: BorderSide(color: Color(0xFF1E2638), width: 1)),
      ),
      child: BottomNavigationBar(
        currentIndex: _selectedTab,
        onTap: (index) {
          _triggerHaptic(HapticFeedbackType.selection);
          setState(() {
            _selectedTab = index;
          });
        },
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedItemColor: const Color(0xFF00FF88),
        unselectedItemColor: Colors.white38,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
        unselectedLabelStyle: const TextStyle(fontSize: 11),
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.shield_outlined),
            activeIcon: const Icon(Icons.shield),
            label: _t("tabGuard"),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.lightbulb_outline),
            activeIcon: const Icon(Icons.lightbulb),
            label: _t("tabTips"),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.settings_outlined),
            activeIcon: const Icon(Icons.settings),
            label: _t("tabSettings"),
          ),
        ],
      ),
    );
  }
}

enum HapticFeedbackType { selection, medium, heavy }
