import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// Update this to your deployed Render URL, e.g. "https://italksign-api.onrender.com".
/// Use "http://10.0.2.2:8000" for the Android emulator talking to a local `uvicorn` run,
/// or "http://127.0.0.1:8000" for iOS simulator / desktop.
const String kApiBaseUrl = "https://YOUR-RENDER-APP.onrender.com";

const Color kBrandBlue = Color(0xFF2F6690);
const Color kBrandTeal = Color(0xFF3A8891);

void main() => runApp(const HearingPredictorApp());

class HearingPredictorApp extends StatelessWidget {
  const HearingPredictorApp({super.key});

  @override
  Widget build(BuildContext context) {
    final baseScheme = ColorScheme.fromSeed(seedColor: kBrandBlue);
    return MaterialApp(
      title: "iTalkSign Hearing Predictor",
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: baseScheme,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF4F7F9),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: kBrandBlue, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      home: const PredictionPage(),
    );
  }
}

class _FieldSpec {
  final String key;
  final String label;
  final String hint;
  final double min;
  final double max;
  final IconData icon;
  final List<MapEntry<int, String>>? options;

  const _FieldSpec(this.key, this.label, this.hint, this.min, this.max, this.icon,
      {this.options});

  bool get isDropdown => options != null;
}

class _Section {
  final String title;
  final IconData icon;
  final List<_FieldSpec> fields;

  const _Section(this.title, this.icon, this.fields);
}

class PredictionPage extends StatefulWidget {
  const PredictionPage({super.key});

  @override
  State<PredictionPage> createState() => _PredictionPageState();
}

class _PredictionPageState extends State<PredictionPage> {
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  double? _resultValue;
  String? _resultBand;
  String? _errorText;

  static const _yesNo = [
    MapEntry(0, "N/A"),
    MapEntry(1, "Yes"),
    MapEntry(2, "No"),
  ];

  static final List<_Section> _sections = [
    _Section("About you", Icons.person_outline, [
      _FieldSpec("RIDAGEYR", "Age (years)", "20 - 69", 20, 69, Icons.cake_outlined),
      _FieldSpec("RIAGENDR", "Gender", "", 1, 2, Icons.wc_outlined, options: const [
        MapEntry(1, "Male"),
        MapEntry(2, "Female"),
      ]),
      _FieldSpec("RIDRETH3", "Race/ethnicity", "", 1, 7, Icons.groups_outlined, options: const [
        MapEntry(1, "Mexican American"),
        MapEntry(2, "Other Hispanic"),
        MapEntry(3, "Non-Hispanic White"),
        MapEntry(4, "Non-Hispanic Black"),
        MapEntry(6, "Non-Hispanic Asian"),
        MapEntry(7, "Other / Multiracial"),
      ]),
      _FieldSpec("DMDEDUC2", "Education level", "", 1, 5, Icons.school_outlined, options: const [
        MapEntry(1, "Less than 9th grade"),
        MapEntry(2, "9th-11th grade"),
        MapEntry(3, "High school grad / GED"),
        MapEntry(4, "Some college / AA degree"),
        MapEntry(5, "College graduate or above"),
      ]),
      _FieldSpec("DMDMARTL", "Marital status", "", 1, 6, Icons.family_restroom_outlined,
          options: const [
            MapEntry(1, "Married"),
            MapEntry(2, "Widowed"),
            MapEntry(3, "Divorced"),
            MapEntry(4, "Separated"),
            MapEntry(5, "Never married"),
            MapEntry(6, "Living with partner"),
          ]),
      _FieldSpec("INDFMPIR", "Income-to-poverty ratio", "0 - 5", 0, 5, Icons.payments_outlined),
    ]),
    _Section("Hearing & noise history", Icons.hearing_outlined, [
      _FieldSpec("AUQ054", "Self-rated hearing", "", 1, 5, Icons.record_voice_over_outlined,
          options: const [
            MapEntry(1, "Excellent"),
            MapEntry(2, "Good"),
            MapEntry(3, "A little trouble"),
            MapEntry(4, "Moderate trouble"),
            MapEntry(5, "Deaf"),
          ]),
      _FieldSpec("AUQ191", "Ringing/buzzing in ears (past yr)", "", 0, 2, Icons.graphic_eq,
          options: _yesNo),
      _FieldSpec("AUQ300", "Ever used firearms", "", 0, 2, Icons.sports_outlined, options: _yesNo),
      _FieldSpec(
          "AUQ320", "Hearing protection when shooting", "", 0, 5, Icons.shield_outlined,
          options: const [
            MapEntry(0, "N/A"),
            MapEntry(1, "Always"),
            MapEntry(2, "Usually"),
            MapEntry(3, "Sometimes"),
            MapEntry(4, "Seldom"),
            MapEntry(5, "Never"),
          ]),
      _FieldSpec("AUQ331", "Ever had job noise exposure", "", 0, 2, Icons.factory_outlined,
          options: _yesNo),
      _FieldSpec("AUQ350", "Ever very loud noise at work", "", 0, 2, Icons.volume_up_outlined,
          options: _yesNo),
      _FieldSpec("AUQ370", "Off-work loud noise exposure", "", 0, 2, Icons.music_note_outlined,
          options: _yesNo),
    ]),
  ];

  static final List<_FieldSpec> _allFields = _sections.expand((s) => s.fields).toList();

  final Map<String, TextEditingController> _controllers = {
    for (final f in _allFields)
      if (!f.isDropdown) f.key: TextEditingController(),
  };
  final Map<String, int?> _selected = {
    for (final f in _allFields)
      if (f.isDropdown) f.key: null,
  };

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Color _bandColor(String band) {
    switch (band) {
      case "normal hearing":
        return Colors.green;
      case "mild hearing loss":
        return Colors.amber.shade800;
      case "moderate hearing loss":
        return Colors.orange.shade800;
      default:
        return Colors.red.shade700;
    }
  }

  IconData _bandIcon(String band) {
    switch (band) {
      case "normal hearing":
        return Icons.check_circle_outline;
      case "mild hearing loss":
        return Icons.info_outline;
      case "moderate hearing loss":
        return Icons.warning_amber_outlined;
      default:
        return Icons.error_outline;
    }
  }

  Future<void> _predict() async {
    setState(() {
      _errorText = null;
      _resultValue = null;
      _resultBand = null;
    });
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      final body = <String, dynamic>{
        for (final f in _allFields)
          f.key: f.isDropdown ? _selected[f.key] : num.parse(_controllers[f.key]!.text),
      };
      final response = await http
          .post(
            Uri.parse("$kApiBaseUrl/predict"),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 20));

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200) {
        setState(() {
          _resultValue = (data['predicted_pta4_db_hl'] as num).toDouble();
          _resultBand = data['interpretation'] as String;
        });
      } else {
        setState(() => _errorText = "${data['detail'] ?? response.body}");
      }
    } catch (e) {
      setState(() => _errorText = "Couldn't reach the server. Check your connection and try again.");
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 130,
            pinned: true,
            backgroundColor: kBrandBlue,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
              title: const Text("Hearing Risk Predictor",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [kBrandBlue, kBrandTeal],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Align(
                  alignment: Alignment.bottomRight,
                  child: Padding(
                    padding: EdgeInsets.only(right: 12, bottom: 40),
                    child: Icon(Icons.hearing, size: 56, color: Colors.white24),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: kBrandBlue.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: kBrandBlue),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              "iTalkSign uses your answers to estimate hearing-threshold severity (dB HL) "
                              "so we can suggest the right assistive tools for you.",
                              style: TextStyle(fontSize: 13, color: Colors.grey.shade800, height: 1.3),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    for (final section in _sections) ...[
                      Row(
                        children: [
                          Icon(section.icon, size: 20, color: kBrandBlue),
                          const SizedBox(width: 8),
                          Text(section.title,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            children: [
                              for (final f in section.fields) ...[
                                if (f.isDropdown)
                                  DropdownButtonFormField<int>(
                                    initialValue: _selected[f.key],
                                    isExpanded: true,
                                    decoration: InputDecoration(
                                      labelText: f.label,
                                      prefixIcon: Icon(f.icon, size: 20),
                                    ),
                                    items: [
                                      for (final entry in f.options!)
                                        DropdownMenuItem(
                                          value: entry.key,
                                          child: Text("${entry.key} - ${entry.value}"),
                                        ),
                                    ],
                                    onChanged: _loading
                                        ? null
                                        : (value) => setState(() => _selected[f.key] = value),
                                    validator: (value) => value == null ? "Required" : null,
                                  )
                                else
                                  TextFormField(
                                    controller: _controllers[f.key],
                                    enabled: !_loading,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: InputDecoration(
                                      labelText: f.label,
                                      hintText: f.hint,
                                      prefixIcon: Icon(f.icon, size: 20),
                                    ),
                                    validator: (value) {
                                      if (value == null || value.trim().isEmpty) {
                                        return "Required";
                                      }
                                      final parsed = num.tryParse(value);
                                      if (parsed == null) return "Enter a valid number";
                                      if (parsed < f.min || parsed > f.max) {
                                        return "Must be ${f.min}–${f.max}";
                                      }
                                      return null;
                                    },
                                  ),
                                if (f != section.fields.last) const SizedBox(height: 12),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    SizedBox(
                      height: 52,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kBrandBlue,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _loading ? null : _predict,
                        icon: _loading
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.hearing),
                        label: Text(_loading ? "Predicting…" : "Predict",
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: _resultBand != null
                          ? _ResultCard(
                              key: const ValueKey("result"),
                              value: _resultValue!,
                              band: _resultBand!,
                              color: _bandColor(_resultBand!),
                              icon: _bandIcon(_resultBand!),
                            )
                          : _errorText != null
                              ? _ErrorCard(key: const ValueKey("error"), message: _errorText!)
                              : const SizedBox.shrink(key: ValueKey("empty")),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final double value;
  final String band;
  final Color color;
  final IconData icon;

  const _ResultCard({
    super.key,
    required this.value,
    required this.band,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 36),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("${value.toStringAsFixed(1)} dB HL",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: color)),
                const SizedBox(height: 2),
                Text(band[0].toUpperCase() + band.substring(1),
                    style: TextStyle(fontSize: 14, color: color.withValues(alpha: 0.9))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;

  const _ErrorCard({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.08),
        border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 12),
          Expanded(child: Text(message, style: const TextStyle(color: Colors.red, fontSize: 14))),
        ],
      ),
    );
  }
}
