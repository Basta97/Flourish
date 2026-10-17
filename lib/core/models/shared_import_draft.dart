class SharedImportDraft {
  const SharedImportDraft({
    required this.source,
    required this.rawText,
    this.recognizedText,
    this.imagePath,
    this.createdAt,
    this.id,
    this.sender,
    this.packageName,
  });

  final String source;
  final String rawText;
  final String? recognizedText;
  final String? imagePath;
  final DateTime? createdAt;

  /// Set for messages from the detection queue: the queue entry, and who
  /// sent it (SMS sender or notification title) from which app.
  final String? id;
  final String? sender;
  final String? packageName;

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

    // Detection queue rows name their fields text/receivedAt.
    final created = map['createdAt'] ?? map['receivedAt'];
    return SharedImportDraft(
      source: (map['source'] ?? 'shortcut').toString(),
      rawText: (map['rawText'] ?? map['text'] ?? '').toString(),
      recognizedText: normalize(map['recognizedText']),
      imagePath: normalize(map['imagePath']),
      createdAt: created == null ? null : DateTime.tryParse(created.toString()),
      id: normalize(map['id']),
      sender: normalize(map['sender']),
      packageName: normalize(map['packageName']),
    );
  }
}
