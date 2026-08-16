using MediatR;

namespace Kairos.Application.Features.Network.Queries.GetNetworkSuggestions;

public record GetNetworkSuggestionsQuery(
    int CurrentUserId,
    int Page     = 1,
    int PageSize = 20) : IRequest<IReadOnlyList<UserSuggestionDto>>;

public record UserSuggestionDto(
    int     Id,
    string  FullName,
    string? Title,
    string? AvatarUrl,
    string? Location,
    string? Bio,
    string? Role,
    /// <summary>Conexiones aceptadas que tiene esa persona.</summary>
    int     FollowersCount,
    /// <summary>
    /// Estado de la relación con el usuario actual: <c>none</c>,
    /// <c>pending_sent</c>, <c>pending_received</c> o <c>connected</c>.
    ///
    /// Reemplaza al antiguo booleano "lo sigo": con solicitudes de por medio,
    /// sí/no dejaba fuera los dos estados intermedios y el botón no podía saber
    /// qué ofrecer.
    /// </summary>
    string  ConnectionStatus);
