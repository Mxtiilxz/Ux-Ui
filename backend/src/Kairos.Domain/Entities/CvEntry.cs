// ── CvEntry ──────────────────────────────────────────────────
// Un ítem del currículum: una formación o una experiencia laboral.
//
// Existe porque el CV se armaba desde user_activities, la bitácora de uso de
// la red social. Solo la creación de publicaciones escribía ahí, así que el
// documento salía casi vacío y, cuando salía lleno, listaba likes y
// comentarios: un registro de actividad, no un currículum.
//
// Las entradas de formación las carga el liceo con el CSV del curso; las de
// experiencia las agrega el propio alumno desde su perfil. Ambas se editan
// desde el perfil, de modo que el PDF es un reflejo de lo que el alumno ve en
// pantalla y no un segundo formulario que mantener aparte.

namespace Kairos.Domain.Entities;

public static class CvEntryKind
{
    public const string Education  = "education";
    public const string Experience = "experience";

    public static bool IsValid(string? value) => value is Education or Experience;
}

public class CvEntry
{
    public int    Id     { get; set; }
    public int    UserId { get; set; }
    public User   User   { get; set; } = null!;

    /// <summary>"education" o "experience".</summary>
    public string Kind { get; set; } = CvEntryKind.Education;

    /// <summary>Especialidad cursada, o cargo desempeñado.</summary>
    public string Title { get; set; } = string.Empty;

    /// <summary>Liceo o empresa.</summary>
    public string Organization { get; set; } = string.Empty;

    /// <summary>Curso, o descripción de las funciones.</summary>
    public string? Detail { get; set; }

    public int? StartYear { get; set; }

    /// <summary>Null si sigue en curso.</summary>
    public int? EndYear { get; set; }

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}
