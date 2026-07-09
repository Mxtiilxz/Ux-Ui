using MediatR;

namespace Kairos.Application.Features.Matching.Commands.SetQuickMatchVisibility;

public record SetQuickMatchVisibilityCommand(int UserId, bool Visible) : IRequest<bool>;
