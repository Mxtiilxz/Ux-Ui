using Kairos.Application.Features.Network.Commands.SendConnectionRequest;
using MediatR;

namespace Kairos.Application.Features.Network.Commands.RespondToConnectionRequest;

/// <summary>
/// Acepta o rechaza una solicitud recibida. Rechazar borra la fila: no hay
/// razón para guardar un "no" y bloquearía un intento posterior.
/// </summary>
public record RespondToConnectionRequestCommand(
    int  CurrentUserId,
    int  RequesterId,
    bool Accept) : IRequest<ConnectionState>;
