// ── UserSkill ────────────────────────────────────────────────
// Tabla puente: qué competencias tiene cada estudiante.
// v1: etiqueta binaria (la tiene / no la tiene), sin nivel de dominio.

namespace Kairos.Domain.Entities;

public class UserSkill
{
    public int  UserId  { get; set; }
    public User User    { get; set; } = null!;

    public int   SkillId { get; set; }
    public Skill Skill   { get; set; } = null!;
}
