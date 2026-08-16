using Kairos.Domain.Entities;
using Kairos.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;

namespace Kairos.Infrastructure.Persistence;

/// <summary>
/// Catálogo base de competencias de Quick Match.
///
/// Vive aquí, y no dentro de <see cref="DevDataSeeder"/>, porque ese seeder solo
/// corre en desarrollo: en producción la tabla <c>skills</c> quedaba vacía y
/// Quick Match no funcionaba en absoluto — un alumno no tenía competencias que
/// elegir y una empresa no tenía por qué buscar.
///
/// Es un punto de partida, no una lista cerrada. El personal del liceo puede
/// agregar y quitar competencias desde el panel de administración
/// (<c>POST</c> y <c>DELETE /api/skills</c>) para reflejar sus especialidades
/// sin esperar un despliegue.
/// </summary>
public static class SkillCatalog
{
    /// El orden importa: los identificadores los asigna la base de datos según
    /// se insertan, y el backend simulado del modo demo referencia los IDs 1-16.
    /// Las competencias nuevas se agregan al final para que ambos coincidan.
    public static readonly IReadOnlyList<(string Name, SkillCategory Category)> Items =
    [
        ("PLC Siemens",                  SkillCategory.Technical),   //  1
        ("Arduino",                      SkillCategory.Technical),   //  2
        ("SolidWorks",                   SkillCategory.Technical),   //  3
        ("AutoCAD",                      SkillCategory.Technical),   //  4
        ("Python",                       SkillCategory.Technical),   //  5
        ("C/C++",                        SkillCategory.Technical),   //  6
        ("Redes",                        SkillCategory.Technical),   //  7
        ("Modbus",                       SkillCategory.Technical),   //  8
        ("Robótica industrial",          SkillCategory.Technical),   //  9
        ("Diseño 3D",                    SkillCategory.Technical),   // 10
        ("Inglés B1",                    SkillCategory.Language),    // 11
        ("Inglés B2",                    SkillCategory.Language),    // 12
        ("Inglés C1",                    SkillCategory.Language),    // 13
        ("Práctica en automatización",   SkillCategory.Experience),  // 14
        ("Práctica en TI",               SkillCategory.Experience),  // 15
        ("Proyecto personal publicado",  SkillCategory.Experience),  // 16

        // Agregadas después, cubriendo especialidades del liceo que la lista
        // original dejaba fuera. El personal puede seguir ampliándola desde el
        // panel sin tocar este archivo.
        ("Soldadura al arco",            SkillCategory.Technical),   // 17
        ("Instalaciones eléctricas",     SkillCategory.Technical),   // 18
        ("Mantenimiento mecánico",       SkillCategory.Technical),   // 19
        ("Torno y fresado CNC",          SkillCategory.Technical),   // 20
        ("Neumática e hidráulica",       SkillCategory.Technical),   // 21
        ("Lectura de planos",            SkillCategory.Technical),   // 22
        ("Prevención de riesgos",        SkillCategory.Technical),   // 23
        ("Práctica en mantenimiento",    SkillCategory.Experience),  // 24
        ("Licencia de conducir clase B", SkillCategory.Experience),  // 25
    ];

    /// <summary>
    /// Inserta las competencias del catálogo que aún no existan, comparando por
    /// nombre sin distinguir mayúsculas.
    ///
    /// Solo agrega: nunca borra ni renombra. Si el personal del liceo eliminó una
    /// competencia a propósito, un despliegue posterior la resucitaría, así que
    /// el catálogo base solo se siembra cuando la tabla está vacía.
    /// </summary>
    public static async Task SeedAsync(ApplicationDbContext db, CancellationToken cancellationToken = default)
    {
        if (await db.Skills.AnyAsync(cancellationToken)) return;

        db.Skills.AddRange(Items.Select(item => new Skill
        {
            Name     = item.Name,
            Category = item.Category,
        }));

        await db.SaveChangesAsync(cancellationToken);
    }
}
