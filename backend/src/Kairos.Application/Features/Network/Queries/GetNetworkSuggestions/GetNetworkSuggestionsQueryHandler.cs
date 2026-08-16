using Kairos.Application.Common.Interfaces;
using Kairos.Domain.Entities;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace Kairos.Application.Features.Network.Queries.GetNetworkSuggestions;

public class GetNetworkSuggestionsQueryHandler(IApplicationDbContext db)
    : IRequestHandler<GetNetworkSuggestionsQuery, IReadOnlyList<UserSuggestionDto>>
{
    public async Task<IReadOnlyList<UserSuggestionDto>> Handle(
        GetNetworkSuggestionsQuery request,
        CancellationToken cancellationToken)
    {
        // Cualquier fila que involucre al usuario actual lo saca de las
        // sugerencias: ya está conectado o hay una solicitud en curso, y en
        // ambos casos volver a proponerlo sería ruido.
        var related = await db.Follows
            .Where(f => f.FollowerId == request.CurrentUserId ||
                        f.FollowedId == request.CurrentUserId)
            .Select(f => f.FollowerId == request.CurrentUserId ? f.FollowedId : f.FollowerId)
            .ToListAsync(cancellationToken);

        var excluded = related.ToHashSet();
        var skip = (request.Page - 1) * request.PageSize;

        return await db.Users
            .Where(u => u.Id != request.CurrentUserId &&
                        !excluded.Contains(u.Id) &&
                        u.Status == "approved")
            .OrderByDescending(u => db.Follows.Count(
                c => c.Status == ConnectionStatus.Accepted &&
                     (c.FollowerId == u.Id || c.FollowedId == u.Id)))
            .Skip(skip)
            .Take(request.PageSize)
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
                "none"))
            .ToListAsync(cancellationToken);
    }
}
