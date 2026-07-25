/// A single medicine entry — one row per medicine name.
class Medicine {
  final int? id;
  final String name;
  final String shelf;
  final String? category;
  final DateTime createdAt;

  Medicine({
    this.id,
    required this.name,
    required this.shelf,
    this.category,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'shelf': shelf,
      'category': category,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Medicine.fromMap(Map<String, dynamic> map) {
    return Medicine(
      id: map['id'] as int?,
      name: map['name'] as String,
      shelf: map['shelf'] as String,
      category: map['category'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}

/// A single reference photo for a medicine (a box can have several —
/// front, back, sides, and later a "new packaging" version).
/// `embedding` stays null until Phase 4 (the matching engine) fills it in.
class MedicinePhoto {
  final int? id;
  final int medicineId;
  final String imagePath;
  final List<double>? embedding;
  final String? label; // e.g. "front", "back", "new-packaging"
  final DateTime createdAt;

  MedicinePhoto({
    this.id,
    required this.medicineId,
    required this.imagePath,
    this.embedding,
    this.label,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Embeddings are stored as a comma-separated string in SQLite since
  /// there's no native vector/array column type.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'medicine_id': medicineId,
      'image_path': imagePath,
      'embedding': embedding?.join(','),
      'label': label,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory MedicinePhoto.fromMap(Map<String, dynamic> map) {
    final embeddingStr = map['embedding'] as String?;
    return MedicinePhoto(
      id: map['id'] as int?,
      medicineId: map['medicine_id'] as int,
      imagePath: map['image_path'] as String,
      embedding: (embeddingStr == null || embeddingStr.isEmpty)
          ? null
          : embeddingStr.split(',').map(double.parse).toList(),
      label: map['label'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
