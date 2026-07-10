using Kairos.Application.Common.Exceptions;
using Kairos.Application.Common.Interfaces;
using Kairos.Application.Features.Matching.Queries.GetQuickMatchTemplate;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace Kairos.Application.Features.Matching.Commands.SetQuickMatchTemplate;

public class SetQuickMatchTemplateCommandHandler(IApplicationDbContext db)
    : IRequestHandler<SetQuickMatchTemplateCommand, QuickMatchTemplateDto>
{
    private const int MaxLength = 1000;

    public async Task<QuickMatchTemplateDto> Handle(SetQuickMatchTemplateCommand request, CancellationToken cancellationToken)
    {
        var user = await db.Users.FirstOrDefaultAsync(u => u.Id == request.CompanyId, cancellationToken)
            ?? throw new KeyNotFoundException("Usuario no encontrado.");

        if (user.Role != "company")
            throw new ForbiddenException("Solo las empresas pueden personalizar el mensaje de contacto.");

        var trimmed = request.Template?.Trim();

        if (!string.IsNullOrEmpty(trimmed) && trimmed.Length > MaxLength)
            trimmed = trimmed[..MaxLength];

        // Vacío = volver al mensaje por defecto (se guarda null).
        user.QuickMatchMessageTemplate = string.IsNullOrWhiteSpace(trimmed) ? null : trimmed;
        await db.SaveChangesAsync(cancellationToken);

        return string.IsNullOrWhiteSpace(user.QuickMatchMessageTemplate)
            ? new QuickMatchTemplateDto(QuickMatchDefaults.MessageTemplate, IsDefault: true)
            : new QuickMatchTemplateDto(user.QuickMatchMessageTemplate, IsDefault: false);
    }
}
