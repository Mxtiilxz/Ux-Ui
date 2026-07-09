using Kairos.Application.Common.Interfaces;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace Kairos.Application.Features.Matching.Queries.GetMySkills;

public class GetMySkillsQueryHandler(IApplicationDbContext db)
    : IRequestHandler<GetMySkillsQuery, IReadOnlyList<int>>
{
    public async Task<IReadOnlyList<int>> Handle(GetMySkillsQuery request, CancellationToken cancellationToken)
        => await db.UserSkills
            .Where(us => us.UserId == request.UserId)
            .Select(us => us.SkillId)
            .ToListAsync(cancellationToken);
}
