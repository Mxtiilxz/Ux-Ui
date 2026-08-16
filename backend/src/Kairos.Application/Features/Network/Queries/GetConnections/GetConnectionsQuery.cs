using Kairos.Application.Features.Network.Queries.GetNetworkSuggestions;
using MediatR;

namespace Kairos.Application.Features.Network.Queries.GetConnections;

/// <summary>Contactos ya conectados, en cualquiera de los dos sentidos.</summary>
public record GetConnectionsQuery(int CurrentUserId)
    : IRequest<IReadOnlyList<UserSuggestionDto>>;

/// <summary>Solicitudes recibidas y sin responder.</summary>
public record GetConnectionRequestsQuery(int CurrentUserId)
    : IRequest<IReadOnlyList<ConnectionRequestDto>>;

public record ConnectionRequestDto(
    int      Id,
    string   FullName,
    string?  Institution,
    string?  ProfilePictureUrl,
    string?  Bio,
    string?  Role,
    DateTime RequestedAt);
