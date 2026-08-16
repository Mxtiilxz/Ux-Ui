using Kairos.Application.Common.Interfaces;
using Kairos.Domain.Entities;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace Kairos.Application.Features.Jobs.Queries.GetJobs;

public class GetJobsQueryHandler(IApplicationDbContext db)
    : IRequestHandler<GetJobsQuery, GetJobsResult>
{
    public async Task<GetJobsResult> Handle(GetJobsQuery request, CancellationToken cancellationToken)
    {
        var query = db.JobPostings.Include(j => j.Company).AsQueryable();

        // Filter by status
        if (!string.IsNullOrWhiteSpace(request.Status) &&
            Enum.TryParse<JobStatus>(request.Status, ignoreCase: true, out var status))
        {
            query = query.Where(j => j.Status == status);
        }

        // Filter by search term
        if (!string.IsNullOrWhiteSpace(request.Search))
        {
            var term = request.Search.ToLower();
            query = query.Where(j =>
                j.Title.ToLower().Contains(term) ||
                j.Description.ToLower().Contains(term) ||
                (j.Location != null && j.Location.ToLower().Contains(term)) ||
                j.Company.FullName.ToLower().Contains(term));
        }

        var total = await query.CountAsync(cancellationToken);
        var skip  = (request.Page - 1) * request.PageSize;

        var items = await query
            .OrderByDescending(j => j.CreatedAt)
            .Skip(skip)
            .Take(request.PageSize)
            .Select(j => new JobDto(
                j.Id,
                j.Title,
                j.Description,
                j.Location,
                j.ImageUrl,
                j.Status.ToString(),
                j.CreatedAt,
                j.ExpiresAt,
                j.CompanyId,
                j.Company.FullName,
                j.Company.ProfilePictureUrl,
                j.Skills
                    .Select(js => new JobSkillDto(
                        js.Skill.Id,
                        js.Skill.Name,
                        js.Skill.Category.ToString()))
                    .ToList()))
            .ToListAsync(cancellationToken);

        return new GetJobsResult(items, total, skip + items.Count < total);
    }
}
