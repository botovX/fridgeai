// ignore_for_file: avoid_print, deprecated_member_use, use_build_context_synchronously, library_private_types_in_public_api

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

// ─────────────────────────────────────────────
// INSÈRE TA CLÉ API GEMINI ICI (ligne 12)
const String _geminiApiKey = 'COLLE_TA_CLÉ_ICI';
// ─────────────────────────────────────────────

const String _premiumCode = 'FRIDGEAI2024';
const String _adBannerUnitId = 'ca-app-pub-3940256099942544/6300978111';
const String _adInterstitialUnitId = 'ca-app-pub-3940256099942544/1033173712';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await MobileAds.instance.initialize();
  runApp(const FridgeApp());
}

class FridgeApp extends StatefulWidget {
  const FridgeApp({super.key});
  static _FridgeAppState? of(BuildContext context) =>
      context.findAncestorStateOfType<_FridgeAppState>();

  @override
  _FridgeAppState createState() => _FridgeAppState();
}

class _FridgeAppState extends State<FridgeApp> {
  Locale _locale = const Locale('fr');

  void setLocale(Locale locale) {
    setState(() => _locale = locale);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FridgeAI',
      debugShowCheckedModeBanner: false,
      locale: _locale,
      supportedLocales: const [
        Locale('fr'),
        Locale('en'),
        Locale('ar'),
      ],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0A0A0A),
        colorScheme: const ColorScheme.dark(
          background: Color(0xFF0A0A0A),
          surface: Color(0xFF141414),
          primary: Color(0xFF00C853),
          onPrimary: Color(0xFF0A0A0A),
          onBackground: Color(0xFFE0E0E0),
          onSurface: Color(0xFFE0E0E0),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00C853),
            foregroundColor: const Color(0xFF0A0A0A),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            textStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5),
          ),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  File? _image;
  String _result = '';
  bool _isLoading = false;
  bool _isPremium = false;
  String _selectedMode = 'standard';
  BannerAd? _bannerAd;
  InterstitialAd? _interstitialAd;
  int _analyzeCount = 0;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _loadBannerAd();
    _loadInterstitialAd();
  }

  Future<void> _loadPreferences() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _isPremium = prefs.getBool('isPremium') ?? false;
    });
  }

  void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: _adBannerUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdFailedToLoad: (Ad ad, LoadAdError error) {
          ad.dispose();
          _bannerAd = null;
        },
      ),
    )..load();
  }

  void _loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: _adInterstitialUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (InterstitialAd ad) {
          _interstitialAd = ad;
        },
        onAdFailedToLoad: (LoadAdError error) {
          _interstitialAd = null;
        },
      ),
    );
  }

  void _showInterstitialAd() {
    if (!_isPremium && _analyzeCount % 3 == 0 && _interstitialAd != null) {
      _interstitialAd!.show();
      _interstitialAd = null;
      _loadInterstitialAd();
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1280,
      );
      if (picked == null) return;
      setState(() {
        _image = File(picked.path);
        _result = '';
      });
    } catch (e) {
      setState(() => _result = 'Erreur : $e');
    }
  }

  String _buildPrompt(String mode, String langCode) {
    final Map<String, Map<String, String>> prompts =
        <String, Map<String, String>>{
      'standard': <String, String>{
        'fr': 'Tu es un chef cuisinier expert. Analyse ce frigo et propose 3 recettes réalisables avec les ingrédients visibles. Pour chaque recette : nom, ingrédients présents, étapes en 4 lignes max. Réponds en français.',
        'en': 'You are an expert chef. Analyze this fridge and suggest 3 recipes using the visible ingredients. For each recipe: name, available ingredients, steps in max 4 lines. Reply in English.',
        'ar': 'أنت طاهٍ خبير. حلل هذه الثلاجة واقترح 3 وصفات باستخدام المكونات المرئية. لكل وصفة: الاسم، المكونات المتاحة، الخطوات في 4 أسطر كحد أقصى. أجب باللغة العربية.',
      },
      'diet': <String, String>{
        'fr': 'Tu es un nutritionniste expert. Analyse ce frigo et propose 3 recettes DIÉTÉTIQUES légères (moins de 400 calories) avec les ingrédients visibles. Indique les calories approximatives. Réponds en français.',
        'en': 'You are an expert nutritionist. Analyze this fridge and suggest 3 DIET recipes (under 400 calories) using visible ingredients. Include approximate calories. Reply in English.',
        'ar': 'أنت خبير تغذية. حلل هذه الثلاجة واقترح 3 وصفات غذائية خفيفة (أقل من 400 سعرة حرارية). اذكر السعرات الحرارية التقريبية. أجب باللغة العربية.',
      },
      'health': <String, String>{
        'fr': 'Tu es un médecin nutritionniste. Analyse ce frigo et propose 3 recettes THÉRAPEUTIQUES adaptées aux personnes malades (sans sel ajouté, faciles à digérer, anti-inflammatoires). Explique les bienfaits de chaque recette. Réponds en français.',
        'en': 'You are a medical nutritionist. Analyze this fridge and suggest 3 THERAPEUTIC recipes for sick people (no added salt, easy to digest, anti-inflammatory). Explain health benefits. Reply in English.',
        'ar': 'أنت طبيب تغذية. حلل هذه الثلاجة واقترح 3 وصفات علاجية مناسبة للمرضى (بدون ملح مضاف، سهلة الهضم، مضادة للالتهابات). اشرح فوائد كل وصفة. أجب باللغة العربية.',
      },
      'premium': <String, String>{
        'fr': 'Tu es un chef étoilé et nutritionniste. Analyse ce frigo et propose 5 recettes variées avec les ingrédients visibles. Pour chaque recette : nom gastronomique, ingrédients avec quantités précises, étapes détaillées, valeurs nutritionnelles, et liste de courses pour les ingrédients manquants. Réponds en français.',
        'en': 'You are a Michelin-star chef and nutritionist. Analyze this fridge and suggest 5 varied recipes. For each: gourmet name, ingredients with exact quantities, detailed steps, nutritional values, shopping list for missing items. Reply in English.',
        'ar': 'أنت طاهٍ حائز على نجمة ميشلان وخبير تغذية. حلل هذه الثلاجة واقترح 5 وصفات متنوعة. لكل وصفة: اسم فاخر، مكونات بكميات دقيقة، خطوات مفصلة، قيم غذائية، قائمة تسوق للمكونات الناقصة. أجب باللغة العربية.',
      },
    };

    final String mode0 =
        (mode == 'premium' && !_isPremium) ? 'standard' : mode;
    final Map<String, String> modePrompts =
        prompts[mode0] ?? prompts['standard']!;
    return modePrompts[langCode] ?? modePrompts['fr']!;
  }

  Future<void> _analyzeImage() async {
    final AppLocalizations l10n = AppLocalizations.of(context)!;

    if (_image == null) {
      setState(() => _result = l10n.noImageSelected);
      return;
    }

    if (_selectedMode == 'premium' && !_isPremium) {
      _showPremiumDialog();
      return;
    }

    setState(() {
      _isLoading = true;
      _result = '';
    });

    try {
      final String langCode =
          FridgeApp.of(context)?._locale.languageCode ?? 'fr';
      final List<int> imageBytes = await _image!.readAsBytes();
      final String base64Image = base64Encode(imageBytes);
      final String prompt = _buildPrompt(_selectedMode, langCode);

      final String url =
          'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$_geminiApiKey';

      final Map<String, Object> payload = <String, Object>{
        'contents': <Object>[
          <String, Object>{
            'parts': <Object>[
              <String, Object>{'text': prompt},
              <String, Object>{
                'inline_data': <String, Object>{
                  'mime_type': 'image/jpeg',
                  'data': base64Image,
                }
              },
            ]
          }
        ],
        'generationConfig': <String, Object>{
          'temperature': 0.7,
          'maxOutputTokens': _isPremium ? 2048 : 1024,
        }
      };

      final http.Response response = await http.post(
        Uri.parse(url),
        headers: <String, String>{'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode != 200) {
        setState(() {
          _result = '${l10n.errorTitle} (${response.statusCode})';
          _isLoading = false;
        });
        return;
      }

      final Map<String, dynamic> decoded =
          jsonDecode(response.body) as Map<String, dynamic>;
      final List<dynamic> candidates =
          decoded['candidates'] as List<dynamic>;
      final Map<String, dynamic> firstCandidate =
          candidates[0] as Map<String, dynamic>;
      final Map<String, dynamic> content =
          firstCandidate['content'] as Map<String, dynamic>;
      final List<dynamic> parts = content['parts'] as List<dynamic>;
      final Map<String, dynamic> firstPart =
          parts[0] as Map<String, dynamic>;
      final String text = firstPart['text'] as String;

      _analyzeCount++;
      _showInterstitialAd();

      setState(() {
        _result = text.trim();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _result = '${AppLocalizations.of(context)!.errorTitle} : $e';
        _isLoading = false;
      });
    }
  }

  void _showPremiumDialog() {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final TextEditingController controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141414),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(l10n.premiumTitle,
            style: const TextStyle(color: Color(0xFF00C853))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(l10n.premiumDesc,
                style: const TextStyle(color: Color(0xFFD0D0D0))),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: l10n.premiumCode,
                hintStyle:
                    const TextStyle(color: Color(0xFF555555)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: Color(0xFF2A2A2A)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: Color(0xFF00C853)),
                ),
              ),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler',
                style: TextStyle(color: Color(0xFF555555))),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim() == _premiumCode) {
                final SharedPreferences prefs =
                    await SharedPreferences.getInstance();
                await prefs.setBool('isPremium', true);
                setState(() => _isPremium = true);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(l10n.premiumSuccess),
                    backgroundColor: const Color(0xFF00C853),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(l10n.premiumError),
                    backgroundColor: Colors.redAccent,
                  ),
                );
              }
            },
            child: Text(l10n.premiumActivate),
          ),
        ],
      ),
    );
  }

  void _showLanguageDialog() {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141414),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(l10n.languageTitle,
            style: const TextStyle(color: Color(0xFF00C853))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _languageTile('🇫🇷  Français', const Locale('fr'), ctx),
            _languageTile('🇬🇧  English', const Locale('en'), ctx),
            _languageTile('🇸🇦  العربية', const Locale('ar'), ctx),
          ],
        ),
      ),
    );
  }

  Widget _languageTile(String label, Locale locale, BuildContext ctx) {
    final bool isSelected =
        FridgeApp.of(context)?._locale.languageCode == locale.languageCode;
    return ListTile(
      title: Text(label,
          style: TextStyle(
              color: isSelected
                  ? const Color(0xFF00C853)
                  : const Color(0xFFD0D0D0))),
      trailing: isSelected
          ? const Icon(Icons.check, color: Color(0xFF00C853))
          : null,
      onTap: () {
        FridgeApp.of(context)?.setLocale(locale);
        Navigator.pop(ctx);
      },
    );
  }

  Widget _modeChip(String mode, String label, IconData icon) {
    final bool isSelected = _selectedMode == mode;
    final bool isLocked = mode == 'premium' && !_isPremium;
    return GestureDetector(
      onTap: () {
        if (isLocked) {
          _showPremiumDialog();
        } else {
          setState(() => _selectedMode = mode);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF00C853)
              : const Color(0xFF141414),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF00C853)
                : const Color(0xFF2A2A2A),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              isLocked ? Icons.lock : icon,
              size: 16,
              color: isSelected
                  ? const Color(0xFF0A0A0A)
                  : const Color(0xFF888888),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? const Color(0xFF0A0A0A)
                    : const Color(0xFF888888),
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0A),
        elevation: 0,
        title: Row(
          children: <Widget>[
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Color(0xFF00C853),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Text(l10n.appTitle,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700)),
            const Spacer(),
            if (_isPremium)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF00C853).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('✨ Premium',
                    style: TextStyle(
                        color: Color(0xFF00C853), fontSize: 12)),
              ),
          ],
        ),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.language, color: Color(0xFF00C853)),
            onPressed: _showLanguageDialog,
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  // Zone image
                  GestureDetector(
                    onTap: () => _pickImage(ImageSource.gallery),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      height: 220,
                      decoration: BoxDecoration(
                        color: const Color(0xFF141414),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _image != null
                              ? const Color(0xFF00C853)
                              : const Color(0xFF2A2A2A),
                          width: 1.5,
                        ),
                      ),
                      child: _image != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Image.file(_image!,
                                  fit: BoxFit.cover,
                                  width: double.infinity),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
               
