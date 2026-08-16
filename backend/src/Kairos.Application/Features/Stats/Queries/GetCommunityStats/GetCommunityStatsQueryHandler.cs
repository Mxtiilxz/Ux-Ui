using Kairos.Application.Common.Interfaces;
using Kairos.Domain.Entities;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace Kairos.Application.Features.Stats.Queries.GetCommunityStats;

public class GetCommunityStatsQueryHandler(IApplicationDbContext db)
    : IRequestHandler<GetCommunityStatsQuery, CommunityStats>
{
    private const int Limit = 6;

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

        // Oferta de talento: qué sabe hacer el liceo.
        var topSkills = await db.Skills
            .Select(s => new SkillSupply(s.Id, s.Name, s.UserSkills.Count))
            .Where(s => s.StudentCount > 0)
            .OrderByDescending(s => s.StudentCount)
            .ThenBy(s => s.Name)
            .Take(Limit)
            .ToListAsync(cancellationToken);

        // Demanda real: qué piden las empresas. Antes esto se estimaba buscando
        // el nombre de un oficio dentro del texto libre de la oferta; ahora sale
        // de las competencias que la propia empresa marcó al publicarla.
        var topDemand = await db.Skills
            .Select(s => new SkillDemand(
                s.Id,
                s.Name,
                s.JobPostings.Count(js => js.JobPosting.Status == JobStatus.Open)))
            .Where(s => s.JobCount > 0)
            .OrderByDescending(s => s.JobCount)
            .ThenBy(s => s.Name)
            .Take(Limit)
            .ToListAsync(cancellationToken);

        return new CommunityStats(students, companies, activeJobs, topSkills, topDemand);
    }
}
