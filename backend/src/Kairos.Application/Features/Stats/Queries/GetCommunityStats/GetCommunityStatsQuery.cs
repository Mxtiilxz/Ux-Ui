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

public record SkillDemand(int Id, string Name, int StudentCount);

public record TradeDemand(string Name, int JobCount);

public record CommunityStats(
    int Students,
    int Companies,
    int ActiveJobs,
    IReadOnlyList<SkillDemand> TopSkills,
    IReadOnlyList<TradeDemand> TopTrades);
