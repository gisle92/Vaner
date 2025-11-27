// lib/habit_suggestions.dart

class HabitCategory {
  final String id;
  final String label;
  final String emoji;

  const HabitCategory({
    required this.id,
    required this.label,
    required this.emoji,
  });
}

const List<HabitCategory> habitCategories = [
  HabitCategory(id: "health", label: "Helse", emoji: "💊"),
  HabitCategory(id: "workout", label: "Trening", emoji: "💪"),
  HabitCategory(id: "mind", label: "Mental", emoji: "🧠"),
  HabitCategory(id: "social", label: "Sosialt", emoji: "👥"),
  HabitCategory(id: "other", label: "Annet", emoji: "✨"),
];

const Map<String, List<String>> habitSuggestions = {
  "health": [
    "Drikk et glass vann",
    "Gå en 5-minutters tur",
    "Ta trappene én gang i dag",
    "Legg deg 15 minutter tidligere",
  ],
  "workout": [
    "10 push-ups",
    "10 knebøy",
    "1 min planke",
    "5 minutter uttøying",
  ],
  "mind": [
    "2 minutter pusting",
    "Skriv ned 1 ting du er takknemlig for",
    "1 side i en bok",
    "1 min uten mobil",
  ],
  "social": [
    "Send en melding til en venn",
    "Gi et kompliment i dag",
    "Ring noen du bryr deg om",
  ],
  "other": [
    "Rydd et lite område (5 min)",
    "Planlegg morgendagen",
    "Skriv ned 1 ting du lærte i dag",
  ],
};
