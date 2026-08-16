using Kairos.Application.Common.Interfaces;
using Kairos.Domain.Entities;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace Kairos.Application.Features.Network.Commands.SendConnectionRequest;

public class SendConnectionRequestCommandHandler(IApplicationDbContext db)
    : IRequestHandler<SendConnectionRequestCommand, ConnectionState>
{
    public async Task<ConnectionState> Handle(
        SendConnectionRequestCommand request,
        CancellationToken cancellationToken)
    {
        if (request.RequesterId == request.AddresseeId)
            throw new InvalidOperationException("No puedes conectarte contigo mismo.");

        if (!await db.Users.AnyAsync(u => u.Id == request.AddresseeId, cancellationToken))
            throw new KeyNotFoundException("El usuario no existe.");

        var existing = await db.Follows.FirstOrDefaultAsync(
            f => (f.FollowerId == request.RequesterId && f.FollowedId == request.AddresseeId) ||
                 (f.FollowerId == request.AddresseeId && f.FollowedId == request.RequesterId),
            cancellationToken);

        if (existing is not null)
        {
            if (existing.Status == ConnectionStatus.Accepted)
                return new ConnectionState("connected");

            // La otra persona ya había solicitado conectar y ahora este usuario
            // pulsa el mismo botón: eso es un acuerdo, así que se acepta en vez
            // de dejar dos solicitudes cruzadas esperándose entre sí.
            if (existing.FollowedId == request.RequesterId)
            {
                existing.Status = ConnectionStatus.Accepted;
                existing.RespondedAt = DateTime.UtcNow;
                await db.SaveChangesAsync(cancellationToken);
                return new ConnectionState("connected");
            }

            return new ConnectionState("pending_sent");
        }

        db.Follows.Add(new Follow
        {
            FollowerId = request.RequesterId,
            FollowedId = request.AddresseeId,
            Status     = ConnectionStatus.Pending,
        });

        await db.SaveChangesAsync(cancellationToken);
        return new ConnectionState("pending_sent");
    }
}
