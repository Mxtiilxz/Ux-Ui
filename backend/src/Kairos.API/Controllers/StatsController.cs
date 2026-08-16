using Kairos.Application.Features.Stats.Queries.GetCommunityStats;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Kairos.API.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class StatsController(IMediator mediator) : ControllerBase
{
    /// <summary>Cifras reales de la comunidad para las tarjetas laterales del feed.</summary>
    [HttpGet("community")]
    [ProducesResponseType(typeof(CommunityStats), StatusCodes.Status200OK)]
    public async Task<IActionResult> GetCommunityStats(CancellationToken ct)
        => Ok(await mediator.Send(new GetCommunityStatsQuery(), ct));
}
