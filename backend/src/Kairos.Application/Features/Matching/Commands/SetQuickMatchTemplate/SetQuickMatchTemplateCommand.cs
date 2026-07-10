using Kairos.Application.Features.Matching.Queries.GetQuickMatchTemplate;
using MediatR;

namespace Kairos.Application.Features.Matching.Commands.SetQuickMatchTemplate;

// Template null o vacío = restablecer al mensaje por defecto del sistema.
public record SetQuickMatchTemplateCommand(int CompanyId, string? Template) : IRequest<QuickMatchTemplateDto>;
