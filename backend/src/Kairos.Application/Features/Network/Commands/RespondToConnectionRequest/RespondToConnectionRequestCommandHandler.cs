using Kairos.Application.Common.Interfaces;
using Kairos.Application.Features.Network.Commands.SendConnectionRequest;
using Kairos.Domain.Entities;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace Kairos.Application.Features.Network.Commands.RespondToConnectionRequest;

public class RespondToConnectionRequestCommandHandler(IApplicationDbContext db)
    : IRequestHandler<RespondToConnectionRequestCommand, ConnectionState>
{
    public async Task<ConnectionState> Handle(
        RespondToConnectionRequestCommand request,
        CancellationToken cancellationToken)
    {
        // Solo quien recibió la solicitud puede responderla: se busca con el
        // usuario actual del lado del destinatario, no del solicitante.
        var pending = await db.Follows.FirstOrDefaultAsync(
            f => f.FollowerId == request.RequesterId &&
                 f.FollowedId == request.CurrentUserId &&
                 f.Status == ConnectionStatus.Pending,
            cancellationToken)
            ?? throw new KeyNotFoundException("La solicitud no existe o ya fue respondida.");

        if (request.Accept)
        {
            pending.Status = ConnectionStatus.Accepted;
            pending.RespondedAt = DateTime.UtcNow;
            await db.SaveChangesAsync(cancellationToken);
            return new ConnectionState("connected");
        }

        db.Follows.Remove(pending);
        await db.SaveChangesAsync(cancellationToken);
        return new ConnectionState("none");
    }
}
