import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';

/// Persistierter App-Zustand (DTO). Kapselt die JSON-(De)Serialisierung,
/// getrennt vom AppState — damit die Persistenz austauschbar ist (spaeter
/// Supabase). Die Keys sind exakt die bisherigen (rueckwaertskompatibel).
class PersistedState {
  final int xp;
  final int streak;
  final int shields;
  final DateTime? lastWorkoutDate;
  final DateTime? streakStartDate;
  final String displayName;
  final int seedVersion;
  final Map<String, int> restOverrides;
  final String? selectedProgramName;
  final List<Program> customPrograms;
  final List<CompletedSet> history;
  final List<WorkoutLog> logs;

  const PersistedState({
    required this.xp,
    required this.streak,
    required this.shields,
    required this.lastWorkoutDate,
    required this.streakStartDate,
    required this.displayName,
    required this.seedVersion,
    required this.restOverrides,
    required this.selectedProgramName,
    required this.customPrograms,
    required this.history,
    required this.logs,
  });

  Map<String, dynamic> toJson() => {
        'xp': xp,
        'streak': streak,
        'shields': shields,
        'displayName': displayName,
        'seedVersion': seedVersion,
        'lastWorkoutDate': lastWorkoutDate?.toIso8601String(),
        'streakStartDate': streakStartDate?.toIso8601String(),
        'restOverrides': restOverrides,
        'selectedProgramName': selectedProgramName,
        'customPrograms': customPrograms.map((p) => p.toJson()).toList(),
        'history': history.map((e) => e.toJson()).toList(),
        'logs': logs.map((e) => e.toJson()).toList(),
      };

  factory PersistedState.fromJson(Map<String, dynamic> data) {
    final lwd = data['lastWorkoutDate'] as String?;
    final ssd = data['streakStartDate'] as String?;
    final ro = data['restOverrides'] as Map<String, dynamic>? ?? {};
    return PersistedState(
      xp: data['xp'] as int? ?? 0,
      streak: data['streak'] as int? ?? 0,
      shields: data['shields'] as int? ?? 1,
      displayName: data['displayName'] as String? ?? 'Athlet',
      seedVersion: data['seedVersion'] as int? ?? 0,
      lastWorkoutDate: lwd != null ? DateTime.tryParse(lwd) : null,
      streakStartDate: ssd != null ? DateTime.tryParse(ssd) : null,
      restOverrides: ro.map((k, v) => MapEntry(k, v as int)),
      selectedProgramName: data['selectedProgramName'] as String?,
      customPrograms: (data['customPrograms'] as List? ?? [])
          .map((e) => Program.fromJson(e as Map<String, dynamic>))
          .toList(),
      history: (data['history'] as List? ?? [])
          .map((e) => CompletedSet.fromJson(e as Map<String, dynamic>))
          .toList(),
      logs: (data['logs'] as List? ?? [])
          .map((e) => WorkoutLog.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Lokale Persistenz ueber shared_preferences (JSON). Einzige Stelle, die den
/// konkreten Speicher kennt.
class LocalStore {
  static const String _key = 'newprime_state_v1';

  /// Liest den gespeicherten Zustand. Gibt null zurueck, wenn nichts vorhanden
  /// ODER die Daten beschaedigt sind (Aufrufer behandelt beides als Neustart).
  Future<PersistedState?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return null;
    try {
      return PersistedState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> save(PersistedState state) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(state.toJson()));
  }
}
