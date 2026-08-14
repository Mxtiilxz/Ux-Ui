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
  final List<String> skills;
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

    return JobModel(
      id: json['id'].toString(),
      company: json['companyName'] as String? ?? 'Empresa',
      title: json['title'] as String? ?? '',
      location: json['location'] as String? ?? 'Chile',
      type: OpportunityType.job,
      description: json['description'] as String? ?? '',
      skills: const [],
      logoUrl: json['companyAvatarUrl'] as String? ?? '',
      postedDate: postedDate,
      salary: null,
      imageUrl: json['imageUrl'] as String?,
      specializations: const [],
    );
  }
}
