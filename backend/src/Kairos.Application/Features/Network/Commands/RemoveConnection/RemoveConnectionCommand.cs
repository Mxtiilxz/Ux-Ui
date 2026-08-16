using MediatR;

namespace Kairos.Application.Features.Network.Commands.RemoveConnection;

/// <summary>
/// Deshace la relación con otro usuario, sea una conexión ya aceptada o una
/// solicitud propia todavía sin responder.
/// </summary>
public record RemoveConnectionCommand(int CurrentUserId, int OtherUserId) : IRequest;
