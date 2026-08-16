// ── JobPostingSkill ──────────────────────────────────────────
// Competencia que una oferta laboral solicita. Es la contraparte de UserSkill:
// el alumno declara lo que sabe y la empresa declara lo que busca, ambos sobre
// el mismo catálogo curado.
//
// Sin esta tabla las ofertas y las competencias vivían separadas, así que la
// demanda solo podía estimarse buscando el nombre del oficio dentro del texto
// libre de la oferta.

namespace Kairos.Domain.Entities;

public class JobPostingSkill
{
    public int        JobPostingId { get; set; }
    public JobPosting JobPosting   { get; set; } = null!;

    public int   SkillId { get; set; }
    public Skill Skill   { get; set; } = null!;
}
