using Kairos.Application.Common.Interfaces;
using Kairos.Application.Features.Network.Queries.GetNetworkSuggestions;
using Kairos.Domain.Entities;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace Kairos.Application.Features.Network.Queries.GetConnections;

public class GetConnectionsQueryHandler(IApplicationDbContext db)
    : IRequestHandler<GetConnectionsQuery, IReadOnlyList<UserSuggestionDto>>
{
    public async Task<IReadOnlyList<UserSuggestionDto>> Handle(
        GetConnectionsQuery request,
        CancellationToken cancellationToken)
    {
        // Una conexión aceptada vale en los dos sentidos, así que hay que mirar
        // ambos lados de la fila: da igual quién envió la solicitud.
        //
        // El condicional devuelve el *identificador* del otro extremo, no la
        // entidad. Escrito como `f.FollowerId == yo ? f.Followed : f.Follower`,
        // EF Core no puede traducirlo —un condicional no puede resolverse a dos
        // navegaciones distintas— y lanza InvalidOperationException, que la API
        // convierte en un 409. Con enteros la traducción es directa.
        var contactIds = await db.Follows
            .Where(f => f.Status == ConnectionStatus.Accepted &&
                        (f.FollowerId == request.CurrentUserId ||
                         f.FollowedId == request.CurrentUserId))
            .Select(f => f.FollowerId == request.CurrentUserId
                ? f.FollowedId
                : f.FollowerId)
            .ToListAsync(cancellationToken);

        if (contactIds.Count == 0) return [];

        // El orden se aplica sobre la entidad y no sobre el DTO ya proyectado,
        // por el mismo motivo: después de proyectar, EF ya no sabe a qué columna
        // corresponde cada campo del registro.
        return await db.Users
            .Where(u => contactIds.Contains(u.Id))
            .OrderBy(u => u.FullName)
            .Select(u => new UserSuggestionDto(
                u.Id,
                u.FullName,
                u.Institution,
                u.ProfilePictureUrl,
                null,
                u.Bio,
                u.Role,
                db.Follows.Count(c => c.Status == ConnectionStatus.Accepted &&
                                      (c.FollowerId == u.Id || c.FollowedId == u.Id)),
                "connected"))
            .ToListAsync(cancellationToken);
    }
}

public class GetConnectionRequestsQueryHandler(IApplicationDbContext db)
    : IRequestHandler<GetConnectionRequestsQuery, IReadOnlyList<ConnectionRequestDto>>
{
    public async Task<IReadOnlyList<ConnectionRequestDto>> Handle(
        GetConnectionRequestsQuery request,
        CancellationToken cancellationToken)
    {
        return await db.Follows
            .Where(f => f.FollowedId == request.CurrentUserId &&
                        f.Status == ConnectionStatus.Pending)
            .OrderByDescending(f => f.CreatedAt)
            .Select(f => new ConnectionRequestDto(
                f.Follower.Id,
                f.Follower.FullName,
                f.Follower.Institution,
                f.Follower.ProfilePictureUrl,
                f.Follower.Bio,
                f.Follower.Role,
                f.CreatedAt))
            .ToListAsync(cancellationToken);
    }
}
