// ── SavedJob ─────────────────────────────────────────────────
// Oferta que un alumno marcó para revisar después.
//
// Antes esto vivía en un Set dentro del widget de Flutter, así que se perdía
// al recargar la página: el marcador de "guardar" no guardaba nada y filtrar
// por guardados no podía funcionar.

namespace Kairos.Domain.Entities;

public class SavedJob
{
    public int  UserId { get; set; }
    public User User   { get; set; } = null!;

    public int        JobId { get; set; }
    public JobPosting Job   { get; set; } = null!;

    public DateTime SavedAt { get; set; } = DateTime.UtcNow;
}
