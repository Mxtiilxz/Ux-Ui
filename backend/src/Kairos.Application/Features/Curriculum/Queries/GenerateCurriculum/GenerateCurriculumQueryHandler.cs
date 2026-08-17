using Kairos.Application.Common.Interfaces;
using Kairos.Domain.Entities;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace Kairos.Application.Features.Curriculum.Queries.GenerateCurriculum;

public class GenerateCurriculumQueryHandler(IApplicationDbContext db, ICurriculumGenerator generator)
    : IRequestHandler<GenerateCurriculumQuery, byte[]>
{
    public async Task<byte[]> Handle(GenerateCurriculumQuery request, CancellationToken cancellationToken)
    {
        var user = await db.Users
            .FirstOrDefaultAsync(u => u.Id == request.UserId, cancellationToken)
            ?? throw new KeyNotFoundException($"Usuario {request.UserId} no encontrado.");

        // Las mismas secciones que el alumno ve en su perfil. Antes esto leía
        // user_activities y el documento salía como una bitácora de likes y
        // comentarios en vez de un currículum.
        var entries = await db.CvEntries
            .Where(c => c.UserId == request.UserId)
            .OrderByDescending(c => c.EndYear ?? int.MaxValue)
            .ThenByDescending(c => c.StartYear)
            .ToListAsync(cancellationToken);

        var skills = await db.UserSkills
            .Where(us => us.UserId == request.UserId)
            .Select(us => us.Skill)
            .OrderBy(s => s.Category)
            .ThenBy(s => s.Name)
            .ToListAsync(cancellationToken);

        return generator.Generate(new CurriculumData(
            user,
            entries.Where(e => e.Kind == CvEntryKind.Education).ToList(),
            entries.Where(e => e.Kind == CvEntryKind.Experience).ToList(),
            skills));
    }
}
