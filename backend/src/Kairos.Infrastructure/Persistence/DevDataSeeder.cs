using Kairos.Domain.Entities;
using Kairos.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace Kairos.Infrastructure.Persistence;

public static class DevDataSeeder
{
    public static async Task SeedAsync(IServiceProvider services)
    {
        using var scope = services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();

        // Apply any pending migrations automatically on startup
        await db.Database.MigrateAsync();

        // ── Usuarios de testeo ──────────────────────────────────────────────────
        var testUsers = new[]
        {
            new
            {
                Username    = "kairos_user1",
                Email       = "kairos_user1@kairos.cl",
                Password    = "Kairos2026!",
                FullName    = "Ana González Rojas",
                Role        = "student",
                Institution = "Liceo Técnico Cardenal José María Caro",
                Bio         = "Estudiante de 4° año en Mecatrónica. Apasionada por la automatización y robótica.",
            },
            new
            {
                Username    = "kairos_staff1",
                Email       = "staff1@kairos.cl",
                Password    = "Kairos2026!",
                FullName    = "Carlos Méndez Torres",
                Role        = "staff",
                Institution = "Liceo Técnico Cardenal José María Caro",
                Bio         = "Jefe de Especialidad — Mecatrónica y Automatización Industrial.",
            },
            new
            {
                Username    = "kairos_staff2",
                Email       = "staff2@kairos.cl",
                Password    = "Kairos2026!",
                FullName    = "María Ignacia Fuentes Vera",
                Role        = "staff",
                Institution = "Liceo Técnico Cardenal José María Caro",
                Bio         = "Orientadora vocacional y encargada de vinculación con empresas.",
            },
            new
            {
                Username    = "empresa_kairos",
                Email       = "empresa@kairos.cl",
                Password    = "Kairos2026!",
                FullName    = "Automatización Industrial S.A.",
                Role        = "company",
                Institution = "Santiago, Chile",
                Bio         = "Empresa líder en soluciones de automatización para la industria nacional.",
            },
            new
            {
                Username    = "empresa_kairos2",
                Email       = "empresa2@kairos.cl",
                Password    = "Kairos2026!",
                FullName    = "TechSolutions Chile SpA",
                Role        = "company",
                Institution = "Viña del Mar, Chile",
                Bio         = "Desarrollamos software y sistemas embebidos para la industria minera y energética.",
            },
        };

        int? companyId  = null;
        int? companyId2 = null;
        int? studentId  = null;

        foreach (var seed in testUsers)
        {
            var existing = await db.Users.FirstOrDefaultAsync(u => u.Username == seed.Username);
            if (existing != null)
            {
                if (seed.Username == "empresa_kairos")  companyId  = existing.Id;
                if (seed.Username == "empresa_kairos2") companyId2 = existing.Id;
                if (seed.Role == "student")             studentId  = existing.Id;
                continue;
            }

            var user = new User
            {
                Username     = seed.Username,
                Email        = seed.Email,
                PasswordHash = BCrypt.Net.BCrypt.HashPassword(seed.Password),
                FullName     = seed.FullName,
                Role         = seed.Role,
                Institution  = seed.Institution,
                Bio          = seed.Bio,
                Status       = "approved",
            };
            db.Users.Add(user);
            await db.SaveChangesAsync();

            if (seed.Username == "empresa_kairos")  companyId  = user.Id;
            if (seed.Username == "empresa_kairos2") companyId2 = user.Id;
            if (seed.Role == "student")             studentId  = user.Id;
        }

        // ── Actividades del estudiante (alimentan el CV) ────────────────────────
        if (studentId.HasValue)
        {
            var hasActivities = await db.UserActivities.AnyAsync(a => a.UserId == studentId.Value);
            if (!hasActivities)
            {
                var now = DateTime.UtcNow;
                db.UserActivities.AddRange(
                    new UserActivity
                    {
                        UserId       = studentId.Value,
                        ActivityType = ActivityType.Login,
                        Description  = "Inicio de sesión en la plataforma Kairos",
                        CreatedAt    = now.AddDays(-30),
                    },
                    new UserActivity
                    {
                        UserId       = studentId.Value,
                        ActivityType = ActivityType.PostCreated,
                        Description  = "Publicó un proyecto: 'Brazo robótico controlado por Arduino'",
                        CreatedAt    = now.AddDays(-25),
                    },
                    new UserActivity
                    {
                        UserId       = studentId.Value,
                        ActivityType = ActivityType.PostCreated,
                        Description  = "Compartió avance de práctica: 'Automatización de línea de ensamblaje'",
                        CreatedAt    = now.AddDays(-18),
                    },
                    new UserActivity
                    {
                        UserId       = studentId.Value,
                        ActivityType = ActivityType.CommentPosted,
                        Description  = "Participó en foro técnico sobre sensores industriales",
                        CreatedAt    = now.AddDays(-15),
                    },
                    new UserActivity
                    {
                        UserId       = studentId.Value,
                        ActivityType = ActivityType.ProfileUpdated,
                        Description  = "Actualizó habilidades técnicas: PLC Siemens, Arduino, SolidWorks",
                        CreatedAt    = now.AddDays(-12),
                    },
                    new UserActivity
                    {
                        UserId       = studentId.Value,
                        ActivityType = ActivityType.JobApplied,
                        Description  = "Postulación enviada a: Técnico en Automatización — Automatización Industrial S.A.",
                        CreatedAt    = now.AddDays(-5),
                    },
                    new UserActivity
                    {
                        UserId       = studentId.Value,
                        ActivityType = ActivityType.FollowedUser,
                        Description  = "Conectó con la empresa Automatización Industrial S.A.",
                        CreatedAt    = now.AddDays(-4),
                    },
                    new UserActivity
                    {
                        UserId       = studentId.Value,
                        ActivityType = ActivityType.PostLiked,
                        Description  = "Interactuó con publicación sobre robótica industrial",
                        CreatedAt    = now.AddDays(-2),
                    }
                );
                await db.SaveChangesAsync();
            }
        }

        // ── Catálogo de competencias (Quick Match) ──────────────────────────────
        // Mismo catálogo que en producción: si las dos listas divirgieran, una
        // demo con competencias que la instalación real no tiene sería
        // engañosa. Ver SkillCatalog.
        await SkillCatalog.SeedAsync(db);

        // ── Competencias del estudiante de demo + visibilidad en Quick Match ────
        if (studentId.HasValue)
        {
            var hasUserSkills = await db.UserSkills.AnyAsync(us => us.UserId == studentId.Value);
            if (!hasUserSkills)
            {
                var demoSkillNames = new[] { "PLC Siemens", "Arduino", "SolidWorks", "Inglés B2", "Práctica en automatización" };
                var demoSkills = await db.Skills.Where(s => demoSkillNames.Contains(s.Name)).ToListAsync();
                foreach (var skill in demoSkills)
                {
                    db.UserSkills.Add(new UserSkill { UserId = studentId.Value, SkillId = skill.Id });
                }

                var student = await db.Users.FindAsync(studentId.Value);
                if (student != null) student.QuickMatchVisible = true;

                await db.SaveChangesAsync();
            }
        }

        // ── Estudiantes adicionales visibles en Quick Match (demo) ──────────────
        // Poblamos varios candidatos con competencias variadas para que las
        // búsquedas de las empresas devuelvan resultados realistas y con distintos
        // porcentajes de coincidencia. Todos usan la contraseña Kairos2026!.
        var demoQuickMatchStudents = new[]
        {
            new
            {
                Username = "est_benjamin",
                Email    = "benjamin@kairos.cl",
                FullName = "Benjamín Soto Herrera",
                Bio      = "Estudiante de Mecatrónica, 4° año. Me apasiona la automatización con PLC y la robótica.",
                Skills   = new[] { "PLC Siemens", "Arduino", "Robótica industrial", "Modbus", "Inglés B1", "Práctica en automatización" },
            },
            new
            {
                Username = "est_catalina",
                Email    = "catalina@kairos.cl",
                FullName = "Catalina Rojas Muñoz",
                Bio      = "Especialidad en Automatización. Me encanta el diseño mecánico y el modelado 3D.",
                Skills   = new[] { "PLC Siemens", "AutoCAD", "SolidWorks", "Diseño 3D", "Inglés B2" },
            },
            new
            {
                Username = "est_diego",
                Email    = "diego@kairos.cl",
                FullName = "Diego Fuentes Araya",
                Bio      = "Estudiante de Informática. Programo en Python y C/C++, y administro redes.",
                Skills   = new[] { "Python", "C/C++", "Redes", "Inglés B2", "Práctica en TI" },
            },
            new
            {
                Username = "est_fernanda",
                Email    = "fernanda@kairos.cl",
                FullName = "Fernanda Morales Díaz",
                Bio      = "Mecatrónica. Diseño robots y publico mis proyectos personales.",
                Skills   = new[] { "Arduino", "SolidWorks", "Diseño 3D", "Robótica industrial", "Proyecto personal publicado" },
            },
            new
            {
                Username = "est_ignacio",
                Email    = "ignacio@kairos.cl",
                FullName = "Ignacio Castro Vega",
                Bio      = "Electrónica industrial. Trabajo con microcontroladores y comunicación Modbus.",
                Skills   = new[] { "C/C++", "Arduino", "Modbus", "Redes", "Inglés B1" },
            },
            new
            {
                Username = "est_valentina",
                Email    = "valentina@kairos.cl",
                FullName = "Valentina Pérez Silva",
                Bio      = "Automatización industrial. Programación de PLC y robótica de línea.",
                Skills   = new[] { "PLC Siemens", "Modbus", "Robótica industrial", "Práctica en automatización", "Inglés C1" },
            },
        };

        var skillIdByName = await db.Skills.ToDictionaryAsync(s => s.Name, s => s.Id);

        foreach (var seed in demoQuickMatchStudents)
        {
            if (await db.Users.AnyAsync(u => u.Username == seed.Username)) continue;

            var user = new User
            {
                Username          = seed.Username,
                Email             = seed.Email,
                PasswordHash      = BCrypt.Net.BCrypt.HashPassword("Kairos2026!"),
                FullName          = seed.FullName,
                Role              = "student",
                Institution       = "Liceo Técnico Cardenal José María Caro",
                Bio               = seed.Bio,
                Status            = "approved",
                QuickMatchVisible = true,
            };
            db.Users.Add(user);
            await db.SaveChangesAsync();

            foreach (var skillName in seed.Skills)
            {
                if (skillIdByName.TryGetValue(skillName, out var skillId))
                    db.UserSkills.Add(new UserSkill { UserId = user.Id, SkillId = skillId });
            }
            await db.SaveChangesAsync();
        }

        // ── Ofertas laborales de demo ──────────────────────────────────────────
        if (companyId.HasValue)
        {
            var hasJobs = await db.JobPostings.AnyAsync(j => j.CompanyId == companyId.Value);
            if (!hasJobs)
            {
                db.JobPostings.AddRange(
                    new JobPosting
                    {
                        CompanyId   = companyId.Value,
                        Title       = "Técnico en Automatización Industrial",
                        Description = "Buscamos egresado o estudiante de último año en Mecatrónica o Automatización. " +
                                      "Trabajarás en proyectos de automatización de líneas de producción con PLCs Siemens y Schneider. " +
                                      "Jornada completa, contrato por proyecto con posibilidad de planta.",
                        Location    = "Pudahuel, Santiago",
                        Status      = JobStatus.Open,
                        CreatedAt   = DateTime.UtcNow.AddDays(-7),
                        ExpiresAt   = DateTime.UtcNow.AddDays(23),
                    },
                    new JobPosting
                    {
                        CompanyId   = companyId.Value,
                        Title       = "Práctica Profesional — Programación PLC",
                        Description = "Práctica de 6 meses para estudiantes de 4° año de Mecatrónica. " +
                                      "Aprenderás a programar PLCs en lenguaje Ladder y FBD, además de configurar HMI industriales. " +
                                      "Asignación mensual + colación.",
                        Location    = "Maipú, Santiago",
                        Status      = JobStatus.Open,
                        CreatedAt   = DateTime.UtcNow.AddDays(-3),
                        ExpiresAt   = DateTime.UtcNow.AddDays(27),
                    }
                );
                await db.SaveChangesAsync();
            }
        }

        if (companyId2.HasValue)
        {
            var hasJobs2 = await db.JobPostings.AnyAsync(j => j.CompanyId == companyId2.Value);
            if (!hasJobs2)
            {
                db.JobPostings.AddRange(
                    new JobPosting
                    {
                        CompanyId   = companyId2.Value,
                        Title       = "Desarrollador de Sistemas Embebidos",
                        Description = "Buscamos técnico con conocimientos en C/C++ para microcontroladores y comunicación industrial (Modbus, CAN). " +
                                      "Proyecto en sector minero, trabajo híbrido con visitas a terreno en faena.",
                        Location    = "Antofagasta / Remoto",
                        Status      = JobStatus.Open,
                        CreatedAt   = DateTime.UtcNow.AddDays(-5),
                        ExpiresAt   = DateTime.UtcNow.AddDays(25),
                    },
                    new JobPosting
                    {
                        CompanyId   = companyId2.Value,
                        Title       = "Práctica — Soporte IT e Infraestructura",
                        Description = "Práctica de 4 meses para estudiantes de Informática o Telecomunicaciones. " +
                                      "Apoyarás al equipo de infraestructura en mantención de redes, servidores Linux y monitoreo de sistemas. " +
                                      "Modalidad presencial en Viña del Mar.",
                        Location    = "Viña del Mar",
                        Status      = JobStatus.Open,
                        CreatedAt   = DateTime.UtcNow.AddDays(-1),
                        ExpiresAt   = DateTime.UtcNow.AddDays(29),
                    }
                );
                await db.SaveChangesAsync();
            }
        }

        // ── Mensaje de contacto personalizado de demo (empresa 2) ──────────────
        // La empresa 1 queda con el mensaje por defecto y la empresa 2 con uno
        // personalizado, para poder demostrar ambos estados de la funcionalidad.
        if (companyId2.HasValue)
        {
            var company2 = await db.Users.FindAsync(companyId2.Value);
            if (company2 != null && string.IsNullOrWhiteSpace(company2.QuickMatchMessageTemplate))
            {
                company2.QuickMatchMessageTemplate =
                    "¡Hola {nombre}! En TechSolutions Chile buscamos jóvenes talentos y tu dominio de " +
                    "{competencias} nos llamó la atención. ¿Coordinamos una entrevista?";
                await db.SaveChangesAsync();
            }
        }

        // ── Posts de demo en el feed ───────────────────────────────────────────
        var hasSeededPosts = await db.Posts.AnyAsync();
        if (!hasSeededPosts && studentId.HasValue && companyId.HasValue)
        {
            var posts = new List<Post>
            {
                new Post
                {
                    AuthorId  = studentId.Value,
                    Content   = "¡Terminé mi proyecto de brazo robótico controlado por Arduino! " +
                                "Fue un desafío increíble aprender programación en C++ y diseñar los servomotores. " +
                                "Gracias a todos los que me apoyaron en Kairos.",
                    Type      = PostType.General,
                    CreatedAt = DateTime.UtcNow.AddHours(-8),
                },
                new Post
                {
                    AuthorId  = companyId.Value,
                    Content   = "¡Estamos buscando talento técnico! " +
                                "Abrimos dos posiciones para egresados y practicantes de Mecatrónica. " +
                                "Si te apasiona la automatización industrial, postula ahora en Kairos.",
                    Type      = PostType.General,
                    CreatedAt = DateTime.UtcNow.AddHours(-3),
                },
            };

            if (companyId2.HasValue)
            {
                posts.Add(new Post
                {
                    AuthorId  = companyId2.Value,
                    Content   = "En TechSolutions Chile estamos creciendo y buscamos nuevos talentos del mundo técnico. " +
                                "Tenemos posiciones abiertas en sistemas embebidos y soporte IT. " +
                                "¡Revisa nuestras ofertas en Kairos y postula hoy!",
                    Type      = PostType.General,
                    CreatedAt = DateTime.UtcNow.AddHours(-1),
                });
            }

            db.Posts.AddRange(posts);
            await db.SaveChangesAsync();
        }
    }
}
