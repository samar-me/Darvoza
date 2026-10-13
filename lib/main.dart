import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'apk_scanner_service.dart';
import 'radar_scanner.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DarvozaApp());
}

class DarvozaApp extends StatelessWidget {
  const DarvozaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Darvoza Cyber Security',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF080C14),
        fontFamily: 'sans-serif',
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00FF88),
          secondary: Color(0xFF00E5FF),
          surface: Color(0xFF111726),
          error: Color(0xFFFF2E63),
        ),
      ),
      home: const DarvozaMainScreen(),
    );
  }
}

class DarvozaMainScreen extends StatefulWidget {
  const DarvozaMainScreen({super.key});

  @override
  State<DarvozaMainScreen> createState() => _DarvozaMainScreenState();
}

class _DarvozaMainScreenState extends State<DarvozaMainScreen> {
  static const MethodChannel _platform =
      MethodChannel('com.darvoza.security/apk_receiver');

  int _selectedTab = 0; // 0: Posbon (Interception), 1: Audit (Tahlil vositasi), 2: Sozlamalar
  bool _isScanning = false;
  double _scanProgress = 0.0;
  String _scanStatusText = "FAYL TAHLIL QILINMOQDA...";
  ApkAnalysisResult? _analysisResult;

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
    HapticFeedback.mediumImpact();
    setState(() {
      _isScanning = true;
      _analysisResult = null;
      _scanProgress = 0.15;
      _scanStatusText = "APK ZIP ARXIVI OCHILMOQDA...";
    });

    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() {
      _scanProgress = 0.45;
      _scanStatusText = "SHA-256 VA IMZOLAR TEKSHIRILMOQDA...";
    });

    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    setState(() {
      _scanProgress = 0.80;
      _scanStatusText = "RUXSATLAR & KIBER TAHDIDLAR BAHOLANMOQDA...";
    });

    try {
      final result = await ApkScannerService.analyzeApk(filePath);
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;

      setState(() {
        _scanProgress = 1.0;
        _isScanning = false;
        _analysisResult = result;
      });

      if (result.isSafe) {
        HapticFeedback.lightImpact();
      } else {
        HapticFeedback.heavyImpact();
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
          content: Text("Xatolik yuz berdi: $e"),
        ),
      );
    }
  }

  Future<void> _pickFileManually() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['apk'],
    );

    if (files.isNotEmpty && files.first.path != null) {
      _runComprehensiveScan(files.first.path!);
    }
  }

  Future<void> _installApk(String path) async {
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
    try {
      final res = await _platform.invokeMethod<bool>('deleteApk', {'path': path});
      if (res == true && mounted) {
        setState(() {
          _analysisResult = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF00FF88),
            content: Text("Zararli APK fayl xotiradan to'liq tozalab tashlandi!"),
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
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0A101D), Color(0xFF060911)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildTopCyberHeader(),
              Expanded(
                child: _isScanning
                    ? _buildScanningHud()
                    : _analysisResult != null
                        ? _buildDetailedThreatReport(_analysisResult!)
                        : _buildTabContent(),
              ),
              if (!_isScanning && _analysisResult == null) _buildCyberBottomNav(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopCyberHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1526).withValues(alpha: 0.6),
        border: const Border(
          bottom: BorderSide(color: Color(0xFF1E293B), width: 1),
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
                  width: 38,
                  height: 38,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFF00FF88).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.shield, color: Color(0xFF00FF88)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    "DARVOZA",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.5,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    "KIBER XAVFSIZLIK QALQONI",
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                      color: Color(0xFF00FF88),
                    ),
                  ),
                ],
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF00FF88).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF00FF88).withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.bolt, color: Color(0xFF00FF88), size: 14),
                SizedBox(width: 4),
                Text(
                  "FAOL",
                  style: TextStyle(
                    color: Color(0xFF00FF88),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
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
        return _buildSystemAuditDashboard();
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
              size: 240,
              primaryColor: const Color(0xFF00FF88),
              statusText: _scanStatusText,
              progress: _scanProgress,
            ),
            const SizedBox(height: 36),
            const Text(
              "NEYRON VA GEVRISTIK TAHLIL",
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.8,
                color: Colors.white60,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "APK tarkibidagi ruxsatnomalar, yashirin dastur kodi va ruxsatsiz masofaviy ulanishlar tekshirilmoqda.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white38, fontSize: 12),
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
          // Markaziy Kiber Gologramma
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF101728),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFF1E293B)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00FF88).withValues(alpha: 0.05),
                  blurRadius: 40,
                  spreadRadius: 10,
                ),
              ],
            ),
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00FF88).withValues(alpha: 0.2),
                            blurRadius: 35,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                    ),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Image.asset(
                        'assets/images/darvoza_logo.png',
                        width: 120,
                        height: 120,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => const Icon(
                          Icons.security,
                          size: 100,
                          color: Color(0xFF00FF88),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  "Avtomatik Posbon Yoqilgan",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Telegram, WhatsApp yoki brauzerdan yuklangan har qanday .apk fayl telefoningizga o'rnatilishidan oldin avtomatik 'Darvoza'da to'xtatiladi.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.white60, height: 1.4),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _pickFileManually,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00FF88),
                      foregroundColor: const Color(0xFF05101E),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 8,
                      shadowColor: const Color(0xFF00FF88).withValues(alpha: 0.4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.file_upload_outlined, size: 22, color: Colors.black87),
                        SizedBox(width: 10),
                        Text(
                          "APK FAYLNI TANLAB SKANERLASH",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Tezkor Statistika Panel
          Row(
            children: [
              _buildStatMiniCard(
                icon: Icons.offline_bolt_outlined,
                title: "100% Offline",
                subtitle: "Maxfiylik kafolatlangan",
                accentColor: const Color(0xFF00E5FF),
              ),
              const SizedBox(width: 12),
              _buildStatMiniCard(
                icon: Icons.verified_outlined,
                title: "SHA-256 Imzo",
                subtitle: "Anti-Modifikatsiya",
                accentColor: const Color(0xFF00FF88),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatMiniCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color accentColor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF1E293B)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: accentColor, size: 24),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 11, color: Colors.white54),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemAuditDashboard() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          "QURILMA KIBER AUDITI",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          "Qurilmangizdagi xavfli kanallar va monitoring ko'rsatkichlari:",
          style: TextStyle(color: Colors.white54, fontSize: 13),
        ),
        const SizedBox(height: 16),
        _buildAuditTile(
          title: "APK Intent Interception",
          desc: "Noma'lum manbalardan kelgan paketlarni tutib olish",
          status: "FAOL",
          statusColor: const Color(0xFF00FF88),
          icon: Icons.shield_outlined,
        ),
        _buildAuditTile(
          title: "Maxsus Imkoniyatlar (Accessibility)",
          desc: "Ilovalar ekran matnlarini o'qishini nazorat qilish",
          status: "HIMOYA OSTIDA",
          statusColor: const Color(0xFF00E5FF),
          icon: Icons.visibility_outlined,
        ),
        _buildAuditTile(
          title: "SMS Hijacking monitoringi",
          desc: "Bank SMS kodlarini tutib olishga urinishlarni to'xtatish",
          status: "KUCHAYTIRILGAN",
          statusColor: const Color(0xFF00FF88),
          icon: Icons.sms_failed_outlined,
        ),
        _buildAuditTile(
          title: "Overlay (Phishing oyna) nazorati",
          desc: "Boshqa dasturlar ustiga soxta oyna ochilishini cheklash",
          status: "MONITORING",
          statusColor: const Color(0xFFFFB800),
          icon: Icons.layers_outlined,
        ),
      ],
    );
  }

  Widget _buildAuditTile({
    required String title,
    required String desc,
    required String status,
    required Color statusColor,
    required IconData icon,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: statusColor, size: 24),
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
                  style: const TextStyle(fontSize: 12, color: Colors.white54),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              status,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsDashboard() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          "SOZLAMALAR & MAXFIYLIK",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        _buildSettingsItem(
          icon: Icons.language,
          title: "Ilova Tili",
          value: "O'zbekcha (Lotin)",
        ),
        _buildSettingsItem(
          icon: Icons.vibration,
          title: "Haptik Tebranish",
          value: "Yoqilgan",
        ),
        _buildSettingsItem(
          icon: Icons.lock_outline,
          title: "Maxfiylik Siyosati",
          value: "100% Offline (Hech qanday ma'lumot uzatilmaydi)",
        ),
        _buildSettingsItem(
          icon: Icons.info_outline,
          title: "Talqin (Versiya)",
          value: "v2.0.0 Cyber Edition",
        ),
      ],
    );
  }

  Widget _buildSettingsItem({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF00FF88), size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 12, color: Colors.white54)),
              ],
            ),
          ),
        ],
      ),
    );
  }

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
          // Kiber Natija Banner
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: statusColor.withValues(alpha: 0.5), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: statusColor.withValues(alpha: 0.15),
                  blurRadius: 30,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(statusIcon, color: statusColor, size: 36),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              res.summaryTitle,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2,
                                color: statusColor,
                              ),
                            ),
                            Text(
                              "${(res.fileSize / (1024 * 1024)).toStringAsFixed(2)} MB • ${res.fileName}",
                              style: const TextStyle(fontSize: 11, color: Colors.white54),
                            ),
                          ],
                        ),
                      ],
                    ),
                    // Xavfsizlik Skori Indeksi
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: statusColor.withValues(alpha: 0.15),
                        border: Border.all(color: statusColor, width: 2),
                      ),
                      child: Center(
                        child: Text(
                          "${res.securityScore}",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  res.reason,
                  style: const TextStyle(fontSize: 13, color: Colors.white70, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Kriptografik Barmoq Izi (SHA-256)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF0B1120),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF1E293B)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.fingerprint, size: 16, color: Color(0xFF00E5FF)),
                    SizedBox(width: 6),
                    Text(
                      "SHA-256 RAQAMLI BARMOQ IZI:",
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF00E5FF)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                SelectableText(
                  res.sha256,
                  style: const TextStyle(fontSize: 11, color: Colors.white60, fontFamily: 'monospace'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Xavfli Ruxsatlar
          if (res.dangerousPermissions.isNotEmpty) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "🔴 Yuqori Xavfli Ruxsatlar (${res.dangerousPermissions.length}):",
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFFFF2E63)),
              ),
            ),
            const SizedBox(height: 8),
            ...res.dangerousPermissions.map((dp) => _buildPermissionCard(dp, isCritical: true)),
            const SizedBox(height: 14),
          ],

          // Standart Ruxsatlar
          if (res.normalPermissions.isNotEmpty) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "🟢 Standart Tizim Huquqlari (${res.normalPermissions.length}):",
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white70),
              ),
            ),
            const SizedBox(height: 8),
            ...res.normalPermissions.map((np) => _buildPermissionCard(np, isCritical: false)),
            const SizedBox(height: 20),
          ],

          // Harakat tugmalari
          Row(
            children: [
              if (res.isSafe)
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _installApk(res.filePath),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00FF88),
                      foregroundColor: const Color(0xFF05101E),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.install_mobile, color: Colors.black87),
                    label: const Text(
                      "XAVFSIZ O'RNATISH",
                      style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1),
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
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.delete_forever_outlined),
                    label: const Text(
                      "TAHDIDNI XOTIRADAN O'CHIRISH",
                      style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1),
                    ),
                  ),
                ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: () {
                  setState(() {
                    _analysisResult = null;
                  });
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: const BorderSide(color: Color(0xFF1E293B)),
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text("Yopish"),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildPermissionCard(PermissionInfo p, {required bool isCritical}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCritical
            ? const Color(0xFFFF2E63).withValues(alpha: 0.08)
            : const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCritical
              ? const Color(0xFFFF2E63).withValues(alpha: 0.3)
              : const Color(0xFF1E293B),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isCritical ? Icons.error_outline : Icons.check_circle_outline,
            color: isCritical ? const Color(0xFFFF2E63) : const Color(0xFF00FF88),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      p.title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: isCritical ? const Color(0xFFFF2E63) : Colors.white,
                      ),
                    ),
                    Text(
                      p.category,
                      style: const TextStyle(fontSize: 10, color: Colors.white38),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
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

  Widget _buildCyberBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0A0F1D),
        border: Border(top: BorderSide(color: Color(0xFF1E293B), width: 1)),
      ),
      child: BottomNavigationBar(
        currentIndex: _selectedTab,
        onTap: (index) {
          HapticFeedback.selectionClick();
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
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.shield_outlined),
            activeIcon: Icon(Icons.shield),
            label: "Posbon",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.security_outlined),
            activeIcon: Icon(Icons.security),
            label: "Kiber Audit",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.tune_outlined),
            activeIcon: Icon(Icons.tune),
            label: "Sozlamalar",
          ),
        ],
      ),
    );
  }
}
