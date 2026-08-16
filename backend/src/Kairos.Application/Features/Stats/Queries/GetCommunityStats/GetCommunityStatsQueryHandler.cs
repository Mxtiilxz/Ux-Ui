using Kairos.Application.Common.Interfaces;
using Kairos.Domain.Entities;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace Kairos.Application.Features.Stats.Queries.GetCommunityStats;

public class GetCommunityStatsQueryHandler(IApplicationDbContext db)
    : IRequestHandler<GetCommunityStatsQuery, CommunityStats>
{
    /// <summary>
    /// Oficios del liceo que se muestran en la tarjeta lateral. La lista es
    /// curada, pero el número que la acompaña ya no: sale de contar ofertas.
    /// </summary>
    private static readonly string[] Trades =
        ["Electricista", "Soldador", "Carpintero", "Mecánico", "Gasfiter"];

    private const int TopSkillsLimit = 6;

    public async Task<CommunityStats> Handle(GetCommunityStatsQuery request, CancellationToken cancellationToken)
    {
        var students = await db.Users
            .CountAsync(u => u.Role == "student" && u.Status == "approved", cancellationToken);

        var companies = await db.Users
            .CountAsync(u => u.Role == "company" && u.Status == "approved", cancellationToken);

        // "Activas" son las abiertas: una oferta cerrada o en borrador no es una
        // oportunidad a la que nadie pueda postular.
        var activeJobs = await db.JobPostings
            .CountAsync(j => j.Status == JobStatus.Open, cancellationToken);

        var topSkills = await db.Skills
            .Select(s => new SkillDemand(s.Id, s.Name, s.UserSkills.Count))
            .Where(s => s.StudentCount > 0)
            .OrderByDescending(s => s.StudentCount)
            .ThenBy(s => s.Name)
            .Take(TopSkillsLimit)
            .ToListAsync(cancellationToken);

        // Las ofertas son texto libre, así que el oficio se busca en el título y
        // en la descripción. Es una aproximación, pero cuenta ofertas que
        // existen, que es la diferencia con lo que había antes.
        var jobs = await db.JobPostings
            .Where(j => j.Status == JobStatus.Open)
            .Select(j => new { j.Title, j.Description })
            .ToListAsync(cancellationToken);

        var topTrades = Trades
            .Select(trade => new TradeDemand(
                trade,
                jobs.Count(j =>
                    j.Title.Contains(trade, StringComparison.OrdinalIgnoreCase) ||
                    j.Description.Contains(trade, StringComparison.OrdinalIgnoreCase))))
            .OrderByDescending(t => t.JobCount)
            .ThenBy(t => t.Name)
            .ToList();

        return new CommunityStats(students, companies, activeJobs, topSkills, topTrades);
    }
}
