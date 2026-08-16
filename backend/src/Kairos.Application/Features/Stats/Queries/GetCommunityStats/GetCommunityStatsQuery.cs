using MediatR;

namespace Kairos.Application.Features.Stats.Queries.GetCommunityStats;

/// <summary>
/// Cifras reales de la plataforma para las tarjetas laterales del feed.
///
/// Existe porque esas tarjetas mostraban números inventados —la cantidad de
/// ofertas por oficio se calculaba como <c>120 - posición * 15</c>—, lo que en
/// una instalación recién creada daba una comunidad activa que no existía.
/// </summary>
public record GetCommunityStatsQuery : IRequest<CommunityStats>;

/// <summary>Cuántos alumnos declararon la competencia. Oferta de talento.</summary>
public record SkillSupply(int Id, string Name, int StudentCount);

/// <summary>Cuántas ofertas abiertas la solicitan. Demanda de las empresas.</summary>
public record SkillDemand(int Id, string Name, int JobCount);

public record CommunityStats(
    int Students,
    int Companies,
    int ActiveJobs,
    IReadOnlyList<SkillSupply> TopSkills,
    IReadOnlyList<SkillDemand> TopDemand);
