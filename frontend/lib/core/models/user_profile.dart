enum UserRole { student, alumni, staff, company }

class SoftSkill {
  const SoftSkill({
    required this.name,
    required this.level,
    this.badge = false,
  });

  final String name;
  final int level;
  final bool badge;
}

class SocioemotionalTest {
  const SocioemotionalTest({
    required this.completed,
    this.completedDate,
    this.skills = const [],
  });

  final bool completed;
  final String? completedDate;
  final List<SoftSkill> skills;
}

class UserProfile {
  const UserProfile({
    required this.id,
    required this.name,
    required this.role,
    required this.title,
    required this.avatarUrl,
    required this.skills,
    required this.bio,
    required this.location,
    required this.connections,
    this.institution,
    this.specialization,
    this.graduationYear,
    this.socioemotionalTest,
    this.quickMatchVisible = false,
  });

  final String id;
  final String name;
  final UserRole role;
  final String title;
  final String avatarUrl;
  final List<String> skills;
  final String bio;
  final String location;
  final int connections;
  final String? institution;
  final String? specialization;
  final int? graduationYear;
  final SocioemotionalTest? socioemotionalTest;
  final bool quickMatchVisible;

  String get initials {
    final parts = name.split(' ');
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }
}
