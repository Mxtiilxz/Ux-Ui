// ============================================================
//  Kairos.Application / Common / Interfaces / ICurriculumGenerator.cs
// ============================================================

using Kairos.Domain.Entities;

namespace Kairos.Application.Common.Interfaces;

/// <summary>
/// Datos que componen el currículum. Son exactamente las secciones que el
/// alumno ve en su perfil: el PDF es un reflejo de esa pantalla, no un
/// documento con vida propia.
/// </summary>
public record CurriculumData(
    User                     User,
    IReadOnlyList<CvEntry>   Education,
    IReadOnlyList<CvEntry>   Experience,
    IReadOnlyList<Skill>     Skills);

public interface ICurriculumGenerator
{
    /// <summary>Genera el CV en PDF y retorna los bytes del archivo.</summary>
    byte[] Generate(CurriculumData data);
}
