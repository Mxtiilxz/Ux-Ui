import '../models/user_profile.dart';
import '../../features/home/data/models/post_model.dart';
import '../../features/jobs/data/models/job_model.dart';
// ── Users ──────────────────────────────────────────────────────────────────────

const List<UserProfile> allUsers = [
  UserProfile(
    id: '1',
    name: 'Matias Silva',
    role: UserRole.student,
    title: 'Estudiante de Mecatronica - 4to Medio',
    avatarUrl:
        'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=500',
    skills: [
      'Arduino',
      'Electronica',
      'Programacion C++',
      'Diseno CAD',
      'Impresion 3D',
    ],
    bio:
        'Estudiante del Liceo Tecnico Cardenal Jose Maria Caro. Apasionado por la robotica y la automatizacion industrial.',
    location: 'La Florida, Santiago',
    connections: 45,
    specialization: 'Mecatronica',
    graduationYear: 2026,
    socioemotionalTest: SocioemotionalTest(
      completed: true,
      completedDate: '15/03/2026',
      skills: [
        SoftSkill(name: 'Trabajo en Equipo', level: 5, badge: true),
        SoftSkill(name: 'Adaptabilidad', level: 4, badge: true),
        SoftSkill(name: 'Comunicacion', level: 4, badge: true),
        SoftSkill(name: 'Presion', level: 3),
        SoftSkill(name: 'Paciencia', level: 5, badge: true),
      ],
    ),
  ),
  UserProfile(
    id: '2',
    name: 'Camila Rojas',
    role: UserRole.student,
    title: 'Estudiante de Automatizacion - 3ro Medio',
    avatarUrl:
        'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=500',
    skills: [
      'PLC',
      'Electricidad Industrial',
      'Instrumentacion',
      'Control de Procesos',
    ],
    bio:
        'Estudiante del area de automatizacion, enfocada en control industrial.',
    location: 'La Florida, Santiago',
    connections: 32,
    specialization: 'Automatizacion',
    graduationYear: 2027,
    socioemotionalTest: SocioemotionalTest(completed: false),
  ),
  UserProfile(
    id: '3',
    name: 'Diego Munoz',
    role: UserRole.alumni,
    title: 'Tecnico en Mecanica Automotriz',
    avatarUrl:
        'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=500',
    skills: ['Mecanica Automotriz', 'Diagnostico', 'Inyeccion Electronica'],
    bio: 'Egresado 2024. Actualmente trabaja en taller automotriz.',
    location: 'La Florida, Santiago',
    connections: 78,
    specialization: 'Mecanica',
    graduationYear: 2024,
  ),
  UserProfile(
    id: '4',
    name: 'Patricia Fernandez',
    role: UserRole.staff,
    title: 'Coordinadora de Practicas',
    avatarUrl:
        'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=500',
    skills: ['Educacion Tecnica', 'Orientacion Vocacional'],
    bio: 'Profesora y coordinadora de practicas profesionales.',
    location: 'La Florida, Santiago',
    connections: 156,
  ),
  UserProfile(
    id: '5',
    name: 'Roberto Castillo',
    role: UserRole.staff,
    title: 'Jefe UTP',
    avatarUrl:
        'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=500',
    skills: ['Gestion Educativa', 'Liderazgo Pedagogico'],
    bio: 'Jefe UTP del Liceo Tecnico Cardenal Jose Maria Caro.',
    location: 'La Florida, Santiago',
    connections: 234,
  ),
  UserProfile(
    id: '6',
    name: 'Andrea Vasquez',
    role: UserRole.company,
    title: 'Gerente de RRHH - TecnoSur SpA',
    avatarUrl:
        'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=500',
    skills: ['Reclutamiento', 'Seleccion', 'Gestion del Talento'],
    bio: 'Gerente de RRHH buscando talento tecnico joven.',
    location: 'San Miguel, Santiago',
    connections: 412,
  ),
  UserProfile(
    id: '7',
    name: 'Valentina Paz',
    role: UserRole.student,
    title: 'Estudiante de Recursos Humanos - 4to Medio',
    avatarUrl:
        'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=500',
    skills: ['Administracion', 'Atencion al Cliente', 'Office'],
    bio: 'Interesada en gestion de personas y desarrollo organizacional.',
    location: 'La Florida, Santiago',
    connections: 28,
    specialization: 'Recursos Humanos',
    graduationYear: 2026,
  ),
  UserProfile(
    id: '8',
    name: 'Carlos Bravo',
    role: UserRole.company,
    title: 'Director de Operaciones - Industrias MetalMec',
    avatarUrl:
        'https://images.unsplash.com/photo-1519085360753-af0119f7cbe7?w=500',
    skills: ['Gestion Industrial', 'Produccion', 'Mantenimiento'],
    bio: 'Buscando tecnicos en mecatronica y mecanica para planta.',
    location: 'Puente Alto, Santiago',
    connections: 287,
  ),
];

final List<UserProfile> suggestedUsers = allUsers
    .where((u) => u.id != '1')
    .toList();

// ── Posts ──────────────────────────────────────────────────────────────────────

final List<PostModel> posts = [
  PostModel(
    id: '1',
    author: allUsers[4],
    content:
        'FERIA DE PRACTICAS 2026\n\nEl proximo viernes 28 de marzo tendremos feria con mas de 20 empresas buscando estudiantes de 4to medio.',
    imageUrl:
        'https://images.unsplash.com/photo-1540575467063-178a50c2df87?w=900',
    likes: 67,
    comments: 23,
    shares: 15,
    timestamp: 'Hace 3 horas',
    isEvent: true,
    eventDate: '28 de marzo, 09:00',
  ),
  PostModel(
    id: '2',
    author: allUsers[0],
    content:
        'Primer lugar en competencia de robotica regional. Gracias a todos por el apoyo del liceo.',
    imageUrl:
        'https://images.unsplash.com/photo-1485827404703-89b55fcc595e?w=900',
    likes: 124,
    comments: 34,
    shares: 12,
    timestamp: 'Hace 1 dia',
  ),
  PostModel(
    id: '3',
    author: allUsers[2],
    content:
        'Un ano desde que egrese y hoy aplico lo aprendido en mecanica automotriz todos los dias.',
    likes: 89,
    comments: 21,
    shares: 8,
    timestamp: 'Hace 2 dias',
  ),
  PostModel(
    id: '4',
    author: allUsers[3],
    content:
        'Charla tecnica: Automatizacion Industrial 4.0. Cupos limitados, inscribete con tu profesor jefe.',
    likes: 45,
    comments: 12,
    shares: 9,
    timestamp: 'Hace 3 dias',
    isEvent: true,
    eventDate: '02 de abril, 15:30',
  ),
  PostModel(
    id: '5',
    author: allUsers[6],
    content:
        'Terminamos simulacion de procesos de seleccion de personal. Gran aprendizaje.',
    imageUrl: 'https://images.unsplash.com/photo-1552664730-d307ca884978?w=900',
    likes: 56,
    comments: 11,
    shares: 4,
    timestamp: 'Hace 4 dias',
  ),
];

// ── Jobs ───────────────────────────────────────────────────────────────────────

const List<JobModel> jobs = [
  JobModel(
    id: '1',
    company: 'TecnoSur SpA',
    title: 'Practicante en Mecatronica',
    location: 'San Miguel, Santiago',
    type: OpportunityType.practice,
    description:
        'Practica en mantencion y programacion de equipos automatizados.',
    skills: ['Arduino', 'Electronica Basica', 'Programacion'],
    salary: r'$240.000/mes',
    logoUrl:
        'https://images.unsplash.com/photo-1565043589221-1a6fd9ae45c7?w=200',
    postedDate: 'Hace 1 dia',
    specializations: ['Mecatronica', 'Automatizacion'],
  ),
  JobModel(
    id: '2',
    company: 'Industrias MetalMec',
    title: 'Tecnico en Mantencion Mecanica',
    location: 'Puente Alto, Santiago',
    type: OpportunityType.job,
    description: 'Mantencion preventiva y correctiva de lineas productivas.',
    skills: ['Mecanica Industrial', 'Lectura de Planos'],
    salary: r'$550.000 - $700.000/mes',
    logoUrl:
        'https://images.unsplash.com/photo-1581092918056-0c4c3acd3789?w=200',
    postedDate: 'Hace 2 dias',
    specializations: ['Mecanica', 'Mecatronica'],
  ),
  JobModel(
    id: '3',
    company: 'AutoServicios La Florida',
    title: 'Practicante Mecanica Automotriz',
    location: 'La Florida, Santiago',
    type: OpportunityType.practice,
    description:
        'Practica para diagnostico y reparacion de vehiculos livianos.',
    skills: ['Mecanica Automotriz', 'Diagnostico Basico'],
    salary: r'$200.000/mes',
    logoUrl:
        'https://images.unsplash.com/photo-1487754180451-c456f719a1fc?w=200',
    postedDate: 'Hace 3 dias',
    specializations: ['Mecanica'],
  ),
  JobModel(
    id: '4',
    company: 'Consultora RH Partners',
    title: 'Asistente de Recursos Humanos',
    location: 'Providencia, Santiago',
    type: OpportunityType.job,
    description:
        'Apoyo en reclutamiento, gestion documental y atencion de colaboradores.',
    skills: ['Administracion', 'Office', 'Comunicacion'],
    salary: r'$480.000 - $580.000/mes',
    logoUrl: 'https://images.unsplash.com/photo-1560179707-f14e90ef3623?w=200',
    postedDate: 'Hace 3 dias',
    specializations: ['Recursos Humanos'],
  ),
  JobModel(
    id: '5',
    company: 'Control Industrial Ltda.',
    title: 'Practicante en Automatizacion',
    location: 'Maipu, Santiago',
    type: OpportunityType.practice,
    description: 'Trabajo con PLC, sensores y sistemas de control.',
    skills: ['PLC', 'Electricidad Industrial', 'Instrumentacion'],
    salary: r'$280.000/mes',
    logoUrl:
        'https://images.unsplash.com/photo-1581092918056-0c4c3acd3789?w=200',
    postedDate: 'Hace 4 dias',
    specializations: ['Automatizacion', 'Mecatronica'],
  ),
];

// ── Misc ───────────────────────────────────────────────────────────────────────

const List<String> trendingSkills = [
  'Soldadura',
  'PLC',
  'AutoCAD',
  'Mantenimiento',
  'CNC',
];
const List<String> highlightedTrades = [
  'Electricista',
  'Soldador',
  'Carpintero',
  'Mecanico',
  'Fontanero',
];

UserProfile currentUserForRole(UserRole role) => switch (role) {
  UserRole.student => allUsers[0],
  UserRole.staff => allUsers[4],
  UserRole.company => allUsers[5],
  UserRole.alumni => allUsers[2],
};
