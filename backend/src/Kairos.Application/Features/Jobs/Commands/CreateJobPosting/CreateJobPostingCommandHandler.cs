using Kairos.Application.Common.Interfaces;
using Kairos.Domain.Entities;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace Kairos.Application.Features.Jobs.Commands.CreateJobPosting;

public class CreateJobPostingCommandHandler(IApplicationDbContext db)
    : IRequestHandler<CreateJobPostingCommand, int>
{
    public async Task<int> Handle(CreateJobPostingCommand request, CancellationToken cancellationToken)
    {
        var posting = new JobPosting
        {
            CompanyId   = request.CompanyId,
            Title       = request.Title,
            Description = request.Description,
            Location    = request.Location,
            ImageUrl    = request.ImageUrl,
            ExpiresAt   = request.ExpiresAt,
            Status      = JobStatus.Open,
        };

        db.JobPostings.Add(posting);
        await db.SaveChangesAsync(cancellationToken);

        // Las competencias se guardan después de tener el Id de la oferta. Se
        // filtran contra el catálogo: un id inexistente violaría la clave
        // foránea y tumbaría la publicación entera por un dato de más.
        var requested = (request.SkillIds ?? []).Distinct().ToList();
        if (requested.Count > 0)
        {
            var valid = await db.Skills
                .Where(s => requested.Contains(s.Id))
                .Select(s => s.Id)
                .ToListAsync(cancellationToken);

            db.JobPostingSkills.AddRange(valid.Select(skillId => new JobPostingSkill
            {
                JobPostingId = posting.Id,
                SkillId      = skillId,
            }));

            await db.SaveChangesAsync(cancellationToken);
        }

        return posting.Id;
    }
}
