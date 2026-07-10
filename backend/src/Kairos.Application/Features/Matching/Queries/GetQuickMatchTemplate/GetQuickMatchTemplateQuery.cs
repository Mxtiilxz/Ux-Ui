using MediatR;

namespace Kairos.Application.Features.Matching.Queries.GetQuickMatchTemplate;

public record GetQuickMatchTemplateQuery(int CompanyId) : IRequest<QuickMatchTemplateDto>;

// Template: plantilla efectiva (la personalizada o, si no hay, la por defecto).
// IsDefault: true cuando la empresa aún no personalizó su mensaje.
public record QuickMatchTemplateDto(string Template, bool IsDefault);
