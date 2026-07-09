using Kairos.Application.Common.Exceptions;
using Kairos.Application.Common.Interfaces;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace Kairos.Application.Features.Matching.Commands.SetQuickMatchVisibility;

public class SetQuickMatchVisibilityCommandHandler(IApplicationDbContext db)
    : IRequestHandler<SetQuickMatchVisibilityCommand, bool>
{
    public async Task<bool> Handle(SetQuickMatchVisibilityCommand request, CancellationToken cancellationToken)
    {
        var user = await db.Users.FirstOrDefaultAsync(u => u.Id == request.UserId, cancellationToken)
            ?? throw new KeyNotFoundException("Usuario no encontrado.");

        if (user.Role != "student")
            throw new ForbiddenException("Solo los estudiantes pueden aparecer en Quick Match.");

        user.QuickMatchVisible = request.Visible;
        await db.SaveChangesAsync(cancellationToken);

        return user.QuickMatchVisible;
    }
}
