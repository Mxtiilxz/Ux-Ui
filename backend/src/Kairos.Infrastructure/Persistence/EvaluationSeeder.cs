using Kairos.Domain.Entities;
using Kairos.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;

namespace Kairos.Infrastructure.Persistence;

/// <summary>
/// Puebla una instalación recién desplegada con contenido de muestra, para que
/// quien la revise encuentre la plataforma en funcionamiento en vez de una
/// pantalla vacía.
///
/// Existe porque una base limpia no se puede evaluar: sin publicaciones no hay
/// feed, sin ofertas no hay Quick Match, y un alumno recién registrado queda en
/// estado <c>pending</c> hasta que alguien del liceo lo apruebe. Con esto, las
/// cuentas nacen aprobadas y con datos alrededor.
///
/// A diferencia de <see cref="DevDataSeeder"/>, no lleva contraseñas escritas
/// en el código ni crea cuentas <c>staff</c>: la clave llega por configuración
/// y el primer staff lo crea <see cref="ProductionSeeder"/>. Es idempotente y
/// no hace absolutamente nada salvo que se pida de forma explícita, así que es
/// seguro dejarlo en el arranque.
/// </summary>
public static class EvaluationSeeder
{
    public const string EnabledKey  = "SEED_DEMO_CONTENT";
    public const string PasswordKey = "SEED_DEMO_PASSWORD";

    /// <summary>Correo de la empresa: sirve de marca para no sembrar dos veces.</summary>
    private const string CompanyEmail = "contacto@automatizacion.cl";

    private const string Liceo = "Liceo Técnico Cardenal José María Caro";

    public static async Task SeedAsync(IServiceProvider services, IConfiguration configuration)
    {
        var enabled = configuration[EnabledKey];
        if (!string.Equals(enabled, "true", StringComparison.OrdinalIgnoreCase)) return;

        using var scope = services.CreateScope();
        var db     = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
        var logger = scope.ServiceProvider
            .GetRequiredService<ILoggerFactory>()
            .CreateLogger(typeof(EvaluationSeeder));

        var password = configuration[PasswordKey];
        if (string.IsNullOrWhiteSpace(password))
        {
            logger.LogWarning(
                "{EnabledKey} está activo pero falta {PasswordKey}. No se sembró nada: " +
                "las cuentas de muestra necesitan una contraseña con la que iniciar sesión.",
                EnabledKey, PasswordKey);
            return;
        }

        if (await db.Users.AnyAsync(u => u.Email == CompanyEmail))
        {
            logger.LogInformation(
                "El contenido de muestra ya existe; no se hace nada. " +
                "Conviene quitar {EnabledKey} de las variables de entorno.", EnabledKey);
            return;
        }

        // Las competencias tienen que existir antes de asignarlas.
        await SkillCatalog.SeedAsync(db);

        var hash = BCrypt.Net.BCrypt.HashPassword(password);
        var now  = DateTime.UtcNow;

        // ── Empresa ─────────────────────────────────────────────────────────────
        var company = new User
        {
            Username    = "automatizacion.industrial",
            Email       = CompanyEmail,
            PasswordHash = hash,
            FullName    = "Automatización Industrial S.A.",
            Role        = "company",
            Status      = "approved",
            Institution = "Santiago, Chile",
            Bio         = "Integramos líneas de producción automatizadas para la industria "
                        + "alimentaria y minera. Recibimos practicantes de mecatrónica y "
                        + "electricidad todos los semestres.",
            CreatedAt   = now.AddDays(-60),
            ApprovedAt  = now.AddDays(-60),
        };
        db.Users.Add(company);

        // ── Alumnos ─────────────────────────────────────────────────────────────
        // Competencias variadas a propósito: así una búsqueda de Quick Match
        // devuelve distintos grados de coincidencia y no una lista plana.
        var students = new (string Username, string Email, string FullName, string Bio, string[] Skills)[]
        {
            ("camila.vidal", "camila.vidal@kairos.cl", "Camila Vidal Astorga",
             "4° medio, Mecatrónica. Me interesa la automatización de procesos y la programación de PLC.",
             ["PLC Siemens", "Arduino", "SolidWorks", "Inglés B2", "Práctica en automatización", "Lectura de planos"]),

            ("benjamin.soto", "benjamin.soto@kairos.cl", "Benjamín Soto Herrera",
             "4° medio, Mecatrónica. Trabajo en un brazo robótico como proyecto de título.",
             ["PLC Siemens", "Robótica industrial", "Modbus", "C/C++", "Inglés B1"]),

            ("valentina.paredes", "valentina.paredes@kairos.cl", "Valentina Paredes Lagos",
             "4° medio, Electricidad. Busco práctica en mantenimiento industrial.",
             ["Instalaciones eléctricas", "Mantenimiento mecánico", "Prevención de riesgos",
              "Neumática e hidráulica", "Práctica en mantenimiento"]),

            ("matias.cortes", "matias.cortes@kairos.cl", "Matías Cortés Núñez",
             "4° medio, Mecánica Industrial. Manejo torno CNC y me defiendo en diseño 3D.",
             ["Torno y fresado CNC", "Diseño 3D", "AutoCAD", "Soldadura al arco", "Licencia de conducir clase B"]),
        };

        var studentEntities = students.Select(s => new User
        {
            Username     = s.Username,
            Email        = s.Email,
            PasswordHash = hash,
            FullName     = s.FullName,
            Role         = "student",
            Status       = "approved",
            Institution  = Liceo,
            Bio          = s.Bio,
            // Visibles en Quick Match: es la función que se quiere poder mostrar.
            QuickMatchVisible = true,
            CreatedAt    = now.AddDays(-45),
            ApprovedAt   = now.AddDays(-44),
        }).ToList();

        db.Users.AddRange(studentEntities);
        await db.SaveChangesAsync();

        // ── Competencias de cada alumno ─────────────────────────────────────────
        var catalog = await db.Skills.ToDictionaryAsync(s => s.Name, s => s.Id);

        for (var i = 0; i < students.Length; i++)
        {
            foreach (var skillName in students[i].Skills)
            {
                if (catalog.TryGetValue(skillName, out var skillId))
                    db.UserSkills.Add(new UserSkill { UserId = studentEntities[i].Id, SkillId = skillId });
            }
        }

        var camila = studentEntities[0];
        var benjamin = studentEntities[1];
        var valentina = studentEntities[2];

        // ── Currículum de Camila ────────────────────────────────────────────────
        // Formación y experiencia son lo que alimenta el PDF descargable.
        db.CvEntries.AddRange(
            new CvEntry
            {
                UserId       = camila.Id,
                Kind         = CvEntryKind.Education,
                Title        = "Técnico de Nivel Medio en Mecatrónica",
                Organization = Liceo,
                Detail       = "Especialidad cursada entre 3° y 4° medio.",
                StartYear    = 2024,
                EndYear      = null,
            },
            new CvEntry
            {
                UserId       = camila.Id,
                Kind         = CvEntryKind.Education,
                Title        = "Enseñanza media",
                Organization = Liceo,
                Detail       = "Plan común, 1° a 2° medio.",
                StartYear    = 2022,
                EndYear      = 2023,
            },
            new CvEntry
            {
                UserId       = camila.Id,
                Kind         = CvEntryKind.Experience,
                Title        = "Apoyo en mantenimiento eléctrico",
                Organization = "Panadería San Miguel",
                Detail       = "Revisión de tableros y cambio de luminarias durante el verano. "
                             + "Trabajo de fin de semana coordinado con el liceo.",
                StartYear    = 2025,
                EndYear      = 2025,
            });

        // ── Ofertas laborales, cada una atada a competencias del catálogo ───────
        var jobs = new (string Title, string Description, string Location, string[] Skills)[]
        {
            ("Practicante en automatización industrial",
             "Apoyo al equipo de puesta en marcha de líneas automatizadas: cableado de tableros, "
           + "carga de programas en PLC y registro de pruebas. Práctica de 450 horas con tutor asignado.",
             "Pudahuel, Santiago",
             ["PLC Siemens", "Modbus", "Lectura de planos", "Práctica en automatización"]),

            ("Practicante de mantenimiento mecánico",
             "Mantenimiento preventivo de equipos de planta junto al jefe de turno. "
           + "Se valora manejo de neumática y disposición a trabajar en terreno.",
             "Maipú, Santiago",
             ["Mantenimiento mecánico", "Neumática e hidráulica", "Prevención de riesgos", "Práctica en mantenimiento"]),

            ("Ayudante de diseño y mecanizado",
             "Preparación de planos y programación de piezas en torno CNC para pedidos a medida. "
           + "Ideal para alumnos de Mecánica Industrial.",
             "Quilicura, Santiago",
             ["Torno y fresado CNC", "AutoCAD", "Diseño 3D"]),
        };

        var jobEntities = jobs.Select((j, index) => new JobPosting
        {
            Title       = j.Title,
            Description = j.Description,
            Location    = j.Location,
            CompanyId   = company.Id,
            Status      = JobStatus.Open,
            CreatedAt   = now.AddDays(-20 + index * 5),
        }).ToList();

        db.JobPostings.AddRange(jobEntities);
        await db.SaveChangesAsync();

        for (var i = 0; i < jobs.Length; i++)
        {
            foreach (var skillName in jobs[i].Skills)
            {
                if (catalog.TryGetValue(skillName, out var skillId))
                {
                    db.JobPostingSkills.Add(new JobPostingSkill
                    {
                        JobPostingId = jobEntities[i].Id,
                        SkillId      = skillId,
                    });
                }
            }
        }

        // ── Una postulación, para que la empresa vea su bandeja con contenido ───
        db.JobApplications.Add(new JobApplication
        {
            JobId       = jobEntities[0].Id,
            ApplicantId = camila.Id,
            Status      = ApplicationStatus.Pending,
            CreatedAt   = now.AddDays(-6),
        });

        // ── Feed ────────────────────────────────────────────────────────────────
        db.Posts.AddRange(
            new Post
            {
                AuthorId  = company.Id,
                Type      = PostType.Job,
                Content   = "Abrimos tres cupos de práctica para el segundo semestre en nuestra planta "
                          + "de Pudahuel. Buscamos alumnos de Mecatrónica y Electricidad. "
                          + "Las postulaciones se reciben por la sección Trabajos.",
                CreatedAt = now.AddDays(-18),
            },
            new Post
            {
                AuthorId  = camila.Id,
                Type      = PostType.General,
                Content   = "Terminamos el módulo de neumática con una maqueta que simula una cinta "
                          + "transportadora con dos actuadores. Costó calibrar los sensores, pero quedó "
                          + "funcionando. Gracias al profe Méndez por la paciencia.",
                CreatedAt = now.AddDays(-12),
            },
            new Post
            {
                AuthorId  = benjamin.Id,
                Type      = PostType.General,
                Content   = "Avance del proyecto de título: el brazo robótico ya repite una secuencia "
                          + "grabada de cuatro posiciones. Falta afinar la garra.",
                CreatedAt = now.AddDays(-9),
            },
            new Post
            {
                AuthorId  = company.Id,
                Type      = PostType.Event,
                Content   = "Charla abierta: «Qué mira una empresa en tu práctica». Contamos cómo "
                          + "evaluamos a los practicantes y qué esperamos el primer mes. "
                          + "Sala de actos del liceo, entrada liberada.",
                EventDate = now.AddDays(9).ToString("yyyy-MM-dd"),
                CreatedAt = now.AddDays(-4),
            },
            new Post
            {
                AuthorId  = valentina.Id,
                Type      = PostType.General,
                Content   = "Busco práctica en mantenimiento industrial para enero. Tengo el módulo de "
                          + "prevención de riesgos aprobado y disponibilidad de jornada completa.",
                CreatedAt = now.AddDays(-2),
            });

        // ── Conexiones ──────────────────────────────────────────────────────────
        // Una aceptada y una pendiente: así la pestaña Red muestra tanto la lista
        // de contactos como la burbuja de solicitudes por responder.
        db.Follows.AddRange(
            new Follow
            {
                FollowerId  = company.Id,
                FollowedId  = camila.Id,
                Status      = ConnectionStatus.Accepted,
                CreatedAt   = now.AddDays(-15),
                RespondedAt = now.AddDays(-14),
            },
            new Follow
            {
                FollowerId  = benjamin.Id,
                FollowedId  = camila.Id,
                Status      = ConnectionStatus.Accepted,
                CreatedAt   = now.AddDays(-11),
                RespondedAt = now.AddDays(-11),
            },
            new Follow
            {
                FollowerId = valentina.Id,
                FollowedId = camila.Id,
                Status     = ConnectionStatus.Pending,
                CreatedAt  = now.AddDays(-1),
            });

        await db.SaveChangesAsync();

        logger.LogInformation(
            "Contenido de muestra creado: 1 empresa, {Students} alumnos, {Jobs} ofertas y 5 publicaciones. " +
            "Ya se pueden quitar {EnabledKey} y {PasswordKey} de las variables de entorno.",
            studentEntities.Count, jobEntities.Count, EnabledKey, PasswordKey);
    }
}
