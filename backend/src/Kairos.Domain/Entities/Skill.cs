// ── Skill ────────────────────────────────────────────────────
// Competencia del catálogo curado (habilidad técnica, idioma o
// experiencia previa) que un estudiante puede asociar a su perfil.
// Usado por Quick Match para buscar candidatos por coincidencia.

namespace Kairos.Domain.Entities;

public enum SkillCategory { Technical, Language, Experience }

public class Skill
{
    public int           Id       { get; set; }
    public string         Name     { get; set; } = string.Empty;
    public SkillCategory  Category { get; set; } = SkillCategory.Technical;

    public ICollection<UserSkill> UserSkills { get; set; } = [];
}
