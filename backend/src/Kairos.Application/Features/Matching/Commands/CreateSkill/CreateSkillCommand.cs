using MediatR;

namespace Kairos.Application.Features.Matching.Commands.CreateSkill;

/// <summary>
/// Agrega una competencia al catálogo. Solo el personal del liceo, porque el
/// catálogo es el vocabulario común de Quick Match: si cada alumno pudiera
/// inventar el suyo, "Soldadura" y "soldadura al arco" serían competencias
/// distintas y nadie coincidiría con nadie.
/// </summary>
public record CreateSkillCommand(string Name, string Category) : IRequest<SkillCatalogItem>;

public record SkillCatalogItem(int Id, string Name, string Category, int UserCount);
