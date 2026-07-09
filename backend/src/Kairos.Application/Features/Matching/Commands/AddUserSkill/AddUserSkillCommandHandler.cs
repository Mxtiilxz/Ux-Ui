using Kairos.Application.Common.Exceptions;
using Kairos.Application.Common.Interfaces;
using Kairos.Domain.Entities;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace Kairos.Application.Features.Matching.Commands.AddUserSkill;

public class AddUserSkillCommandHandler(IApplicationDbContext db) : IRequestHandler<AddUserSkillCommand>
{
    public async Task Handle(AddUserSkillCommand request, CancellationToken cancellationToken)
    {
        var user = await db.Users.FirstOrDefaultAsync(u => u.Id == request.UserId, cancellationToken)
            ?? throw new KeyNotFoundException("Usuario no encontrado.");

        if (user.Role != "student")
            throw new ForbiddenException("Solo los estudiantes pueden registrar competencias.");

        var skillExists = await db.Skills.AnyAsync(s => s.Id == request.SkillId, cancellationToken);
        if (!skillExists)
            throw new KeyNotFoundException("Competencia no encontrada.");

        var alreadyHas = await db.UserSkills
            .AnyAsync(us => us.UserId == request.UserId && us.SkillId == request.SkillId, cancellationToken);

        if (!alreadyHas)
        {
            db.UserSkills.Add(new UserSkill { UserId = request.UserId, SkillId = request.SkillId });
            await db.SaveChangesAsync(cancellationToken);
        }
    }
}
