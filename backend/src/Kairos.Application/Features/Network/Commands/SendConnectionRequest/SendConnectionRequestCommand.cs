using MediatR;

namespace Kairos.Application.Features.Network.Commands.SendConnectionRequest;

/// <summary>
/// Envía una solicitud de conexión. La conexión no existe hasta que la otra
/// persona la acepta.
/// </summary>
public record SendConnectionRequestCommand(int RequesterId, int AddresseeId)
    : IRequest<ConnectionState>;

/// <summary>
/// Cómo queda la relación entre ambos: <c>none</c>, <c>pending_sent</c>,
/// <c>pending_received</c> o <c>connected</c>.
/// </summary>
public record ConnectionState(string Status);
