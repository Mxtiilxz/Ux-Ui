using Kairos.Application.Common.Interfaces;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace Kairos.Application.Features.Matching.Commands.RemoveUserSkill;

public class RemoveUserSkillCommandHandler(IApplicationDbContext db) : IRequestHandler<RemoveUserSkillCommand>
{
    public async Task Handle(RemoveUserSkillCommand request, CancellationToken cancellationToken)
    {
        var userSkill = await db.UserSkills
            .FirstOrDefaultAsync(us => us.UserId == request.UserId && us.SkillId == request.SkillId, cancellationToken);

        if (userSkill != null)
        {
            db.UserSkills.Remove(userSkill);
            await db.SaveChangesAsync(cancellationToken);
        }
    }
}
