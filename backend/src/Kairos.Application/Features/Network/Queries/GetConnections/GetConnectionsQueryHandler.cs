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
        var contacts = await db.Follows
            .Where(f => f.Status == ConnectionStatus.Accepted &&
                        (f.FollowerId == request.CurrentUserId ||
                         f.FollowedId == request.CurrentUserId))
            .Select(f => f.FollowerId == request.CurrentUserId ? f.Followed : f.Follower)
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
            .OrderBy(u => u.FullName)
            .ToListAsync(cancellationToken);

        return contacts;
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
