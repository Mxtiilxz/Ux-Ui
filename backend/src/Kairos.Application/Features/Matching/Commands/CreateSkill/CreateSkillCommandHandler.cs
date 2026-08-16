using Kairos.Application.Common.Interfaces;
using Kairos.Domain.Entities;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace Kairos.Application.Features.Matching.Commands.CreateSkill;

public class CreateSkillCommandHandler(IApplicationDbContext db)
    : IRequestHandler<CreateSkillCommand, SkillCatalogItem>
{
    public async Task<SkillCatalogItem> Handle(CreateSkillCommand request, CancellationToken cancellationToken)
    {
        var name = request.Name.Trim();

        if (!Enum.TryParse<SkillCategory>(request.Category, ignoreCase: true, out var category))
            throw new ArgumentException(
                "La categoría debe ser 'Technical', 'Language' o 'Experience'.");

        // Comparación sin distinguir mayúsculas para que "AutoCAD" y "autocad" no
        // convivan como competencias separadas.
        var existing = await db.Skills
            .FirstOrDefaultAsync(s => s.Name.ToLower() == name.ToLower(), cancellationToken);

        if (existing is not null)
            throw new InvalidOperationException(
                $"La competencia \"{existing.Name}\" ya está en el catálogo.");

        var skill = new Skill { Name = name, Category = category };
        db.Skills.Add(skill);
        await db.SaveChangesAsync(cancellationToken);

        return new SkillCatalogItem(skill.Id, skill.Name, skill.Category.ToString(), 0);
    }
}
