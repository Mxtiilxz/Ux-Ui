using Kairos.Application.Common.Interfaces;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace Kairos.Application.Features.Network.Commands.RemoveConnection;

public class RemoveConnectionCommandHandler(IApplicationDbContext db)
    : IRequestHandler<RemoveConnectionCommand>
{
    public async Task Handle(RemoveConnectionCommand request, CancellationToken cancellationToken)
    {
        // La fila puede estar guardada en cualquiera de los dos sentidos según
        // quién solicitó, así que se busca en ambos.
        var relation = await db.Follows.FirstOrDefaultAsync(
            f => (f.FollowerId == request.CurrentUserId && f.FollowedId == request.OtherUserId) ||
                 (f.FollowerId == request.OtherUserId && f.FollowedId == request.CurrentUserId),
            cancellationToken);

        if (relation is null) return; // Idempotente: no había nada que deshacer.

        db.Follows.Remove(relation);
        await db.SaveChangesAsync(cancellationToken);
    }
}
