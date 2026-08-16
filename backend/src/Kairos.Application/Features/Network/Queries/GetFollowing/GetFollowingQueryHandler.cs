using Kairos.Application.Common.Interfaces;
using Kairos.Application.Features.Network.Queries.GetConnections;
using Kairos.Application.Features.Network.Queries.GetNetworkSuggestions;
using MediatR;

namespace Kairos.Application.Features.Network.Queries.GetFollowing;

/// <summary>
/// Contactos con los que se puede conversar.
///
/// Antes devolvía a quien el usuario seguía, sin que la otra persona hubiera
/// aceptado nada: bastaba con pulsar un botón para aparecer en su lista de
/// chat. Ahora son las conexiones aceptadas, que es lo que hace mutuo el
/// contacto.
/// </summary>
public class GetFollowingQueryHandler(IMediator mediator)
    : IRequestHandler<GetFollowingQuery, IReadOnlyList<UserSuggestionDto>>
{
    public Task<IReadOnlyList<UserSuggestionDto>> Handle(
        GetFollowingQuery request,
        CancellationToken cancellationToken) =>
        mediator.Send(new GetConnectionsQuery(request.CurrentUserId), cancellationToken);
}
