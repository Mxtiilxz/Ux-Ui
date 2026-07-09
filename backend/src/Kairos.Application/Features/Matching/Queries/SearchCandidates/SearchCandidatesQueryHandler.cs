using Kairos.Application.Common.Interfaces;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace Kairos.Application.Features.Matching.Queries.SearchCandidates;

public class SearchCandidatesQueryHandler(IApplicationDbContext db)
    : IRequestHandler<SearchCandidatesQuery, IReadOnlyList<CandidateDto>>
{
    public async Task<IReadOnlyList<CandidateDto>> Handle(SearchCandidatesQuery request, CancellationToken cancellationToken)
    {
        var skillIds = request.SkillIds.Distinct().ToList();
        if (skillIds.Count == 0) return [];

        var searchedSkills = await db.Skills
            .Where(s => skillIds.Contains(s.Id))
            .Select(s => new SkillDto(s.Id, s.Name, s.Category.ToString()))
            .ToListAsync(cancellationToken);

        // Traemos solo lo necesario de cada estudiante visible; el ranking (intersección
        // de competencias) se calcula en memoria — el volumen esperado (alumnos de un
        // liceo) hace innecesario un algoritmo de matching más complejo en v1.
        var candidates = await db.Users
            .Where(u => u.Role == "student" && u.QuickMatchVisible && u.Status == "approved")
            .Select(u => new
            {
                u.Id,
                u.FullName,
                u.Institution,
                u.ProfilePictureUrl,
                SkillIds = u.Skills.Select(us => us.SkillId).ToList(),
            })
            .ToListAsync(cancellationToken);

        var results = candidates
            .Select(c =>
            {
                var matchedIds = c.SkillIds.Where(skillIds.Contains).ToHashSet();
                var matched    = searchedSkills.Where(s => matchedIds.Contains(s.Id)).ToList();
                var missing    = searchedSkills.Where(s => !matchedIds.Contains(s.Id)).ToList();
                var percentage = (int)Math.Round(100.0 * matched.Count / searchedSkills.Count);

                return new CandidateDto(
                    c.Id, c.FullName, c.Institution, c.ProfilePictureUrl,
                    matched.Count, searchedSkills.Count, percentage, matched, missing);
            })
            .Where(c => c.MatchCount > 0)
            .OrderByDescending(c => c.MatchCount)
            .ThenBy(c => c.FullName)
            .ToList();

        return results;
    }
}
