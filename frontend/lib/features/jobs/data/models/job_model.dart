enum OpportunityType { practice, job }

extension OpportunityTypeLabel on OpportunityType {
  String get label => switch (this) {
    OpportunityType.practice => 'Practica',
    OpportunityType.job => 'Trabajo',
  };
}

class JobModel {
  const JobModel({
    required this.id,
    required this.company,
    required this.title,
    required this.location,
    required this.type,
    required this.description,
    required this.skills,
    this.skillIds = const [],
    required this.logoUrl,
    required this.postedDate,
    this.salary,
    this.imageUrl,
    this.specializations = const [],
  });

  final String id;
  final String company;
  final String title;
  final String location;
  final OpportunityType type;
  final String description;

  /// Nombres de las competencias que la oferta solicita, para mostrarlas.
  final List<String> skills;

  /// Identificadores de esas mismas competencias, para cruzarlas con el perfil
  /// del alumno sin depender de comparar cadenas.
  final List<int> skillIds;

  final String logoUrl;
  final String postedDate;
  final String? salary;
  final String? imageUrl;
  final List<String> specializations;

  factory JobModel.fromJson(Map<String, dynamic> json) {
    final createdAt = DateTime.tryParse(json['createdAt'] as String? ?? '');
    String postedDate = '';
    if (createdAt != null) {
      final diff = DateTime.now().toUtc().difference(createdAt.toUtc());
      if (diff.inDays == 0) {
        postedDate = 'Hoy';
      } else if (diff.inDays == 1) {
        postedDate = 'Hace 1 día';
      } else {
        postedDate = 'Hace ${diff.inDays} días';
      }
    }

    // Competencias que la empresa marcó al publicar. Antes este campo llegaba
    // siempre vacío porque las ofertas y el catálogo no estaban relacionados.
    final rawSkills = (json['skills'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();

    return JobModel(
      id: json['id'].toString(),
      company: json['companyName'] as String? ?? 'Empresa',
      title: json['title'] as String? ?? '',
      location: json['location'] as String? ?? 'Chile',
      type: OpportunityType.job,
      description: json['description'] as String? ?? '',
      skills: rawSkills
          .map((s) => s['name'] as String? ?? '')
          .where((name) => name.isNotEmpty)
          .toList(growable: false),
      skillIds: rawSkills
          .map((s) => s['id'] as int?)
          .whereType<int>()
          .toList(growable: false),
      logoUrl: json['companyAvatarUrl'] as String? ?? '',
      postedDate: postedDate,
      salary: null,
      imageUrl: json['imageUrl'] as String?,
      specializations: const [],
    );
  }
}
