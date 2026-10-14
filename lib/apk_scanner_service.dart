import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';

enum ThreatLevel { safe, warning, critical }

class ApkAnalysisResult {
  final String fileName;
  final String filePath;
  final int fileSize;
  final String sha256;
  final String md5;
  final int securityScore; // 0 (eng xavfli) dan 100 (to'liq xavfsiz) gacha
  final ThreatLevel threatLevel;
  final List<PermissionInfo> dangerousPermissions;
  final List<PermissionInfo> normalPermissions;
  final String? appName;
  final String? packageName;
  final String? minSdk;
  final String? targetSdk;
  final String summaryTitle;
  final String reason;
  final Uint8List? appIconBytes;
  final String? versionName;
  final bool isFakeSuspect;
  final String? fakeWarningReason;
  final List<String> vulnerabilityNotes;
  final List<String> extractedUrls;
  final List<String> extractedIps;
  final List<String> suspiciousDomains;
  final List<String> botTokens;

  ApkAnalysisResult({
    required this.fileName,
    required this.filePath,
    required this.fileSize,
    required this.sha256,
    required this.md5,
    required this.securityScore,
    required this.threatLevel,
    required this.dangerousPermissions,
    required this.normalPermissions,
    required this.summaryTitle,
    required this.reason,
    required this.vulnerabilityNotes,
    this.appName,
    this.packageName,
    this.versionName,
    this.appIconBytes,
    this.minSdk,
    this.targetSdk,
    this.isFakeSuspect = false,
    this.fakeWarningReason,
    this.extractedUrls = const [],
    this.extractedIps = const [],
    this.suspiciousDomains = const [],
    this.botTokens = const [],
  });

  bool get isSafe => threatLevel == ThreatLevel.safe;
}

class PermissionInfo {
  final String permission;
  final String title;
  final String description;
  final String category; // SMS, Media, Audio, System, Network
  final bool isDangerous;

  PermissionInfo({
    required this.permission,
    required this.title,
    required this.description,
    required this.category,
    required this.isDangerous,
  });
}

class ApkScannerService {
  static final Map<String, PermissionInfo> knownPermissions = {
    // Kiber tahdidlar / O'ta xavfli
    'android.permission.RECEIVE_SMS': PermissionInfo(
      permission: 'android.permission.RECEIVE_SMS',
      title: 'SMS tutib olish',
      description: 'Bank OTP kodlari va shaxsiy SMSlarni foydalanuvchidan yashirin o\'qib olish xavfi.',
      category: 'SMS & Bank',
      isDangerous: true,
    ),
    'android.permission.READ_SMS': PermissionInfo(
      permission: 'android.permission.READ_SMS',
      title: 'SMSlarni o\'qish',
      description: 'Yozishmalar va shaxsiy xabarlarni to\'liq o\'qish imkoniyati.',
      category: 'SMS & Bank',
      isDangerous: true,
    ),
    'android.permission.SEND_SMS': PermissionInfo(
      permission: 'android.permission.SEND_SMS',
      title: 'Yashirin SMS yuborish',
      description: 'Pullik xizmatlar yoki firibgar raqamlarga foydalanuvchi bilmagan holda xabar yuborish.',
      category: 'SMS & Bank',
      isDangerous: true,
    ),
    'android.permission.BIND_ACCESSIBILITY_SERVICE': PermissionInfo(
      permission: 'android.permission.BIND_ACCESSIBILITY_SERVICE',
      title: 'Maxsus imkoniyatlar (Accessibility)',
      description: 'Ekrandagi barcha harakatlarni, klaviatura kiritmalarini (Keylogger) to\'liq nazorat qilish.',
      category: 'Tizim Boshqaruvi',
      isDangerous: true,
    ),
    'android.permission.SYSTEM_ALERT_WINDOW': PermissionInfo(
      permission: 'android.permission.SYSTEM_ALERT_WINDOW',
      title: 'Yashirin oyna (Overlay)',
      description: 'Bank yoki Telegram ilovalari ustiga soxta kirish oynasi joylash (Phishing) xavfi.',
      category: 'Tizim Boshqaruvi',
      isDangerous: true,
    ),
    'android.permission.RECORD_AUDIO': PermissionInfo(
      permission: 'android.permission.RECORD_AUDIO',
      title: 'Mikrofon (Ovoz yozish)',
      description: 'Atrofdagi suhbatlarni yashirin rejimda yozib olish (Spyware).',
      category: 'Maxfiylik',
      isDangerous: true,
    ),
    'android.permission.CAMERA': PermissionInfo(
      permission: 'android.permission.CAMERA',
      title: 'Kamera',
      description: 'Foydalanuvchi bilmagan holda rasm yoki video tasvirga olish.',
      category: 'Maxfiylik',
      isDangerous: true,
    ),
    'android.permission.READ_CONTACTS': PermissionInfo(
      permission: 'android.permission.READ_CONTACTS',
      title: 'Kontaktlarni o\'g\'irlash',
      description: 'Telefon daftarchasidagi barcha raqamlarni tashqi serverga uzatish xavfi.',
      category: 'Shaxsiy Ma\'lumot',
      isDangerous: true,
    ),
    'android.permission.READ_CALL_LOG': PermissionInfo(
      permission: 'android.permission.READ_CALL_LOG',
      title: 'Qo\'ng\'iroqlar tarixi',
      description: 'Barcha kiruvchi va chiquvchi telefon raqamlarni kuzatish.',
      category: 'Shaxsiy Ma\'lumot',
      isDangerous: true,
    ),
    'android.permission.ACCESS_FINE_LOCATION': PermissionInfo(
      permission: 'android.permission.ACCESS_FINE_LOCATION',
      title: 'Aniq GPS joylashuv',
      description: 'Foydalanuvchining real vaqtdagi manzilini metrlargacha aniqlikda kuzatish.',
      category: 'Geolokatsiya',
      isDangerous: true,
    ),
    'android.permission.REQUEST_INSTALL_PACKAGES': PermissionInfo(
      permission: 'android.permission.REQUEST_INSTALL_PACKAGES',
      title: 'Ilova yuklab o\'rnatish',
      description: 'Telefonga orqa fonda boshqa zararli dasturlarni (Dropper) majburlab yuklash.',
      category: 'Tizim',
      isDangerous: true,
    ),
    'android.permission.READ_EXTERNAL_STORAGE': PermissionInfo(
      permission: 'android.permission.READ_EXTERNAL_STORAGE',
      title: 'Xotirani o\'qish',
      description: 'Telefondagi rasmlar, videolar va hujjatlarga kirish.',
      category: 'Fayllar',
      isDangerous: false,
    ),
    'android.permission.WRITE_EXTERNAL_STORAGE': PermissionInfo(
      permission: 'android.permission.WRITE_EXTERNAL_STORAGE',
      title: 'Xotiraga yozish',
      description: 'Fayllarni o\'zgartirish yoki yangi fayl saqlash.',
      category: 'Fayllar',
      isDangerous: false,
    ),
    'android.permission.INTERNET': PermissionInfo(
      permission: 'android.permission.INTERNET',
      title: 'Internetga ulanish',
      description: 'Serverlar bilan tarmoq orqali ma\'lumot almashish.',
      category: 'Tarmoq',
      isDangerous: false,
    ),
    'android.permission.VIBRATE': PermissionInfo(
      permission: 'android.permission.VIBRATE',
      title: 'Tebranish',
      description: 'Bildirishnomalar uchun vibratsiya motorini ishlatish.',
      category: 'Qurilma',
      isDangerous: false,
    ),
  };

  /// APK faylni to'liq kiberxavfsizlik chuqurligida tahlil qilish
  static Future<ApkAnalysisResult> analyzeApk(
    String filePath, {
    Map<dynamic, dynamic>? nativeMetadata,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception("Fayl topilmadi: $filePath");
    }

    final bytes = await file.readAsBytes();
    final fileSize = bytes.length;
    final fileName = filePath.split(Platform.pathSeparator).last;

    // Kriptografik xeshlar (SHA-256 va MD5)
    final sha256Hash = sha256.convert(bytes).toString();
    final md5Hash = md5.convert(bytes).toString();

    List<String> rawPermissions = [];
    String? foundPackageName;
    String? minSdk;
    String? targetSdk;
    final notes = <String>[];

    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      bool hasClassesDex = false;
      bool hasCertificates = false;

      for (final archiveFile in archive) {
        if (archiveFile.name == 'AndroidManifest.xml') {
          final content = archiveFile.content;
          rawPermissions = _extractPermissionsFromAXml(content);
          foundPackageName = _extractPackageNameFromAXml(content);
          minSdk = _extractAttribute(content, 'minSdkVersion');
          targetSdk = _extractAttribute(content, 'targetSdkVersion');
        } else if (archiveFile.name == 'classes.dex') {
          hasClassesDex = true;
        } else if (archiveFile.name.startsWith('META-INF/') &&
            (archiveFile.name.endsWith('.RSA') ||
                archiveFile.name.endsWith('.DSA') ||
                archiveFile.name.endsWith('.EC'))) {
          hasCertificates = true;
        }
      }

      if (!hasCertificates) {
        notes.add('Raqamli imzo sertifikati (META-INF) topilmadi yoki buzilgan.');
      }
      if (!hasClassesDex) {
        notes.add('Standart kod bloklari (classes.dex) aniqlanmadi.');
      }
    } catch (_) {
      rawPermissions = _fallbackSearchPermissions(bytes);
      notes.add('APK arxivi qisman shikastlangan yoki siqilgan.');
    }

    final dangerousList = <PermissionInfo>[];
    final normalList = <PermissionInfo>[];

    for (final perm in rawPermissions) {
      if (knownPermissions.containsKey(perm)) {
        final info = knownPermissions[perm]!;
        if (info.isDangerous) {
          dangerousList.add(info);
        } else {
          normalList.add(info);
        }
      } else {
        // Noma'lum ruxsat
        final short = perm.split('.').last;
        final isCustomDangerous = perm.contains('SMS') ||
            perm.contains('RECORD') ||
            perm.contains('CAMERA') ||
            perm.contains('LOCATION') ||
            perm.contains('ACCESSIBILITY');

        final item = PermissionInfo(
          permission: perm,
          title: short,
          description: 'Maxsus ichki tizim ruxsati',
          category: 'Kengaytirilgan',
          isDangerous: isCustomDangerous,
        );

        if (isCustomDangerous) {
          dangerousList.add(item);
        } else {
          normalList.add(item);
        }
      }
    }

    // Xavfsizlik Skori hisoblash (100 dan boshlanadi)
    int score = 100;

    for (final dp in dangerousList) {
      if (dp.category.contains('SMS') || dp.title.contains('Accessibility')) {
        score -= 35; // Bank va klaviatura poylash uchun eng katta jarima
      } else if (dp.category.contains('Maxfiylik') || dp.category.contains('Tizim')) {
        score -= 20;
      } else {
        score -= 10;
      }
    }

    if (notes.isNotEmpty) {
      score -= (notes.length * 15);
    }

    if (score < 0) score = 0;
    if (score > 100) score = 100;

    ThreatLevel threatLevel;
    String summaryTitle;
    String reason;

    if (score >= 80) {
      threatLevel = ThreatLevel.safe;
      summaryTitle = "XAVFSIZ ILОVA";
      reason = "Fayl toza. Hech qanday shubhali yashirin kod yoki noqonuniy ruxsatlar aniqlanmadi.";
    } else if (score >= 45) {
      threatLevel = ThreatLevel.warning;
      summaryTitle = "DIQQAT: SHUBHALI RUXSATLAR";
      reason = "Ilova maxfiy shaxsiy ma'lumotlarga (kamera, joylashuv yoki audio) kirishni so'ramoqda. O'rnatishda ehtiyot bo'ling.";
    } else {
      threatLevel = ThreatLevel.critical;
      summaryTitle = "XAVFLI: SPYWARE / TROJAN";
      reason = "Ilova o'ta maxfiy huquqlarni (SMS, Accessibility, tizim nazorati) talab qilmoqda. O'rnatish tavsiya etilmaydi!";
    }

    final realAppName = nativeMetadata?['appName'] as String? ?? foundPackageName ?? fileName;
    final realPackageName = nativeMetadata?['packageName'] as String? ?? foundPackageName;
    final realVersionName = nativeMetadata?['versionName'] as String?;
    final iconBytes = nativeMetadata?['iconBytes'] as Uint8List?;

    // 2. SOXTALIKNI ANIQLASH (Fake / Clone Detector)
    bool isFake = false;
    String? fakeReason;

    final lowerName = realAppName.toLowerCase();
    final lowerPkg = (realPackageName ?? '').toLowerCase();

    if (lowerName.contains('click') && !lowerPkg.contains('click')) {
      isFake = true;
      fakeReason = "DIQQAT: Ilova nomi 'Click', lekin uning paketi rasmiy Click'ga tegishli emas! Bu soxta/fishing ilova bo'lishi mumkin.";
    } else if (lowerName.contains('payme') && !lowerPkg.contains('payme')) {
      isFake = true;
      fakeReason = "DIQQAT: Ilova nomi 'Payme', lekin uning paketi rasmiy Payme emas! Bank ma'lumotlarini o'g'irlash xavfi bor.";
    } else if (lowerName.contains('uzum') && !lowerPkg.contains('uzum')) {
      isFake = true;
      fakeReason = "DIQQAT: Ilova nomi 'Uzum', lekin uning paketi rasmiy Uzum emas!";
    } else if (lowerName.contains('telegram') && !lowerPkg.contains('telegram')) {
      isFake = true;
      fakeReason = "DIQQAT: 'Telegram' nomi ostida yashiringan shubhali modifikatsiya!";
    } else if (lowerName.contains('whatsapp') && !lowerPkg.contains('whatsapp')) {
      isFake = true;
      fakeReason = "DIQQAT: 'WhatsApp' nomi ostida yashiringan shubhali modifikatsiya!";
    }

    if (isFake) {
      score = (score > 30) ? 30 : score;
      threatLevel = ThreatLevel.critical;
      summaryTitle = "SOXTA ILОVA (FAKE / CLONE)";
      reason = fakeReason!;
    }

    final urls = (nativeMetadata?['urls'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
    final ips = (nativeMetadata?['ips'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
    final suspiciousDomains = (nativeMetadata?['suspiciousDomains'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
    final botTokens = (nativeMetadata?['botTokens'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];

    if (suspiciousDomains.isNotEmpty || botTokens.isNotEmpty) {
      score = (score > 25) ? 25 : score;
      threatLevel = ThreatLevel.critical;
      summaryTitle = "XAVFLI: YASHIRIN SERVER / BOT ANIQLANDI";
      reason = "Fayl ichida shubhali tashqi domenlar yoki Telegram Bot boshqaruvi aniqlandi!";
    }

    return ApkAnalysisResult(
      fileName: fileName,
      filePath: filePath,
      fileSize: fileSize,
      sha256: sha256Hash,
      md5: md5Hash,
      securityScore: score,
      threatLevel: threatLevel,
      dangerousPermissions: dangerousList,
      normalPermissions: normalList,
      summaryTitle: summaryTitle,
      reason: reason,
      vulnerabilityNotes: notes,
      appName: realAppName,
      packageName: realPackageName,
      versionName: realVersionName,
      appIconBytes: iconBytes,
      minSdk: minSdk,
      targetSdk: targetSdk,
      isFakeSuspect: isFake,
      fakeWarningReason: fakeReason,
      extractedUrls: urls,
      extractedIps: ips,
      suspiciousDomains: suspiciousDomains,
      botTokens: botTokens,
    );
  }

  static List<String> _extractPermissionsFromAXml(dynamic bytes) {
    final Set<String> perms = {};
    final Uint8List uintList = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
    final contentStr = String.fromCharCodes(uintList.where((b) => b >= 32 && b <= 126));

    final matches = RegExp(r'android\.permission\.[A-Z_]+').allMatches(contentStr);
    for (final match in matches) {
      final p = match.group(0);
      if (p != null) perms.add(p);
    }
    return perms.toList();
  }

  static String? _extractPackageNameFromAXml(dynamic bytes) {
    try {
      final Uint8List uintList = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
      final contentStr = String.fromCharCodes(uintList.where((b) => b >= 32 && b <= 126));
      final reg = RegExp(r'package="([^"]+)"');
      final m = reg.firstMatch(contentStr);
      return m?.group(1);
    } catch (_) {
      return null;
    }
  }

  static String? _extractAttribute(dynamic bytes, String attributeName) {
    try {
      final Uint8List uintList = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
      final contentStr = String.fromCharCodes(uintList.where((b) => b >= 32 && b <= 126));
      final reg = RegExp('$attributeName="([^"]+)"');
      final m = reg.firstMatch(contentStr);
      return m?.group(1);
    } catch (_) {
      return null;
    }
  }

  static List<String> _fallbackSearchPermissions(Uint8List bytes) {
    final Set<String> perms = {};
    for (final permKey in knownPermissions.keys) {
      if (_containsSequence(bytes, permKey.codeUnits)) {
        perms.add(permKey);
      }
    }
    return perms.toList();
  }

  static bool _containsSequence(Uint8List source, List<int> pattern) {
    if (pattern.isEmpty || source.length < pattern.length) return false;
    int max = source.length - pattern.length;
    for (int i = 0; i <= max; i++) {
      bool found = true;
      for (int j = 0; j < pattern.length; j++) {
        if (source[i + j] != pattern[j]) {
          found = false;
          break;
        }
      }
      if (found) return true;
    }
    return false;
  }
}
