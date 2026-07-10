using Kairos.Application.Common.Interfaces;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace Kairos.Application.Features.Matching.Queries.GetQuickMatchTemplate;

public class GetQuickMatchTemplateQueryHandler(IApplicationDbContext db)
    : IRequestHandler<GetQuickMatchTemplateQuery, QuickMatchTemplateDto>
{
    public async Task<QuickMatchTemplateDto> Handle(GetQuickMatchTemplateQuery request, CancellationToken cancellationToken)
    {
        var stored = await db.Users
            .Where(u => u.Id == request.CompanyId)
            .Select(u => u.QuickMatchMessageTemplate)
            .FirstOrDefaultAsync(cancellationToken);

        return string.IsNullOrWhiteSpace(stored)
            ? new QuickMatchTemplateDto(QuickMatchDefaults.MessageTemplate, IsDefault: true)
            : new QuickMatchTemplateDto(stored, IsDefault: false);
    }
}
