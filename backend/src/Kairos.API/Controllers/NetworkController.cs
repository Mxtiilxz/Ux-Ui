using System.Security.Claims;
using Kairos.Application.Features.Network.Commands.RemoveConnection;
using Kairos.Application.Features.Network.Commands.RespondToConnectionRequest;
using Kairos.Application.Features.Network.Commands.SendConnectionRequest;
using Kairos.Application.Features.Network.Queries.GetConnections;
using Kairos.Application.Features.Network.Queries.GetFollowing;
using Kairos.Application.Features.Network.Queries.GetNetworkSuggestions;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Kairos.API.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class NetworkController(IMediator mediator) : ControllerBase
{
    private int GetUserId() => int.Parse(
        User.FindFirstValue(ClaimTypes.NameIdentifier)
        ?? User.FindFirstValue("sub")
        ?? throw new UnauthorizedAccessException());

    /// <summary>
    /// Contactos conectados. Se conserva la ruta <c>following</c> porque la usa
    /// la pestaña de chat, pero ya no son "los que sigo": son las conexiones
    /// aceptadas por ambas partes.
    /// </summary>
    [HttpGet("following")]
    [ProducesResponseType(typeof(IReadOnlyList<UserSuggestionDto>), StatusCodes.Status200OK)]
    public async Task<IActionResult> GetFollowing(CancellationToken ct)
        => Ok(await mediator.Send(new GetFollowingQuery(GetUserId()), ct));

    /// <summary>Contactos conectados.</summary>
    [HttpGet("connections")]
    [ProducesResponseType(typeof(IReadOnlyList<UserSuggestionDto>), StatusCodes.Status200OK)]
    public async Task<IActionResult> GetConnections(CancellationToken ct)
        => Ok(await mediator.Send(new GetConnectionsQuery(GetUserId()), ct));

    /// <summary>Solicitudes de conexión recibidas y sin responder.</summary>
    [HttpGet("requests")]
    [ProducesResponseType(typeof(IReadOnlyList<ConnectionRequestDto>), StatusCodes.Status200OK)]
    public async Task<IActionResult> GetRequests(CancellationToken ct)
        => Ok(await mediator.Send(new GetConnectionRequestsQuery(GetUserId()), ct));

    /// <summary>Personas sugeridas: ni conectadas ni con solicitud en curso.</summary>
    [HttpGet("suggestions")]
    [ProducesResponseType(typeof(IReadOnlyList<UserSuggestionDto>), StatusCodes.Status200OK)]
    public async Task<IActionResult> GetSuggestions(
        [FromQuery] int page     = 1,
        [FromQuery] int pageSize = 20,
        CancellationToken ct     = default)
        => Ok(await mediator.Send(new GetNetworkSuggestionsQuery(GetUserId(), page, pageSize), ct));

    /// <summary>
    /// Envía una solicitud de conexión. Si esa persona ya te había enviado una,
    /// se interpreta como aceptación y quedan conectados.
    /// </summary>
    [HttpPost("{userId:int}/connect")]
    [ProducesResponseType(typeof(ConnectionState), StatusCodes.Status200OK)]
    public async Task<IActionResult> Connect(int userId, CancellationToken ct)
        => Ok(await mediator.Send(new SendConnectionRequestCommand(GetUserId(), userId), ct));

    /// <summary>Acepta una solicitud recibida.</summary>
    [HttpPost("requests/{userId:int}/accept")]
    [ProducesResponseType(typeof(ConnectionState), StatusCodes.Status200OK)]
    public async Task<IActionResult> AcceptRequest(int userId, CancellationToken ct)
        => Ok(await mediator.Send(
            new RespondToConnectionRequestCommand(GetUserId(), userId, Accept: true), ct));

    /// <summary>Rechaza una solicitud recibida.</summary>
    [HttpPost("requests/{userId:int}/reject")]
    [ProducesResponseType(typeof(ConnectionState), StatusCodes.Status200OK)]
    public async Task<IActionResult> RejectRequest(int userId, CancellationToken ct)
        => Ok(await mediator.Send(
            new RespondToConnectionRequestCommand(GetUserId(), userId, Accept: false), ct));

    /// <summary>Deshace la conexión, o retira una solicitud propia.</summary>
    [HttpDelete("{userId:int}/connect")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    public async Task<IActionResult> Disconnect(int userId, CancellationToken ct)
    {
        await mediator.Send(new RemoveConnectionCommand(GetUserId(), userId), ct);
        return NoContent();
    }
}
