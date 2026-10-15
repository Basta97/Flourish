class SharedImportDraft {
  const SharedImportDraft({
    required this.source,
    required this.rawText,
    this.recognizedText,
    this.imagePath,
    this.createdAt,
  });

  final String source;
  final String rawText;
  final String? recognizedText;
  final String? imagePath;
  final DateTime? createdAt;

  String get bestText {
    final recognized = recognizedText?.trim() ?? '';
    if (recognized.isNotEmpty) return recognized;
    return rawText.trim();
  }

  factory SharedImportDraft.fromMap(Map<Object?, Object?> map) {
    String? normalize(dynamic value) {
      final text = value?.toString().trim();
      if (text == null || text.isEmpty) return null;
      return text;
    }

    return SharedImportDraft(
      source: (map['source'] ?? 'shortcut').toString(),
      rawText: (map['rawText'] ?? '').toString(),
      recognizedText: normalize(map['recognizedText']),
      imagePath: normalize(map['imagePath']),
      createdAt: map['createdAt'] == null
          ? null
          : DateTime.tryParse(map['createdAt'].toString()),
    );
  }
}
