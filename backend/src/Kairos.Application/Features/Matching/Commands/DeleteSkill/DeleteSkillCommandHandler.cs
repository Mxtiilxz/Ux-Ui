using Kairos.Application.Common.Interfaces;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace Kairos.Application.Features.Matching.Commands.DeleteSkill;

public class DeleteSkillCommandHandler(IApplicationDbContext db)
    : IRequestHandler<DeleteSkillCommand>
{
    public async Task Handle(DeleteSkillCommand request, CancellationToken cancellationToken)
    {
        var skill = await db.Skills
            .FirstOrDefaultAsync(s => s.Id == request.SkillId, cancellationToken)
            ?? throw new KeyNotFoundException("La competencia no existe.");

        // La relación con UserSkill está en cascada, así que borrar aquí sin más
        // arrastraría en silencio la competencia del perfil de cada alumno que la
        // tuviera. Se rechaza y se dice cuántos son, para que el liceo decida.
        var userCount = await db.UserSkills
            .CountAsync(us => us.SkillId == request.SkillId, cancellationToken);

        if (userCount > 0)
            throw new InvalidOperationException(
                $"No se puede eliminar \"{skill.Name}\": {userCount} " +
                $"{(userCount == 1 ? "alumno la tiene" : "alumnos la tienen")} en su perfil.");

        db.Skills.Remove(skill);
        await db.SaveChangesAsync(cancellationToken);
    }
}
