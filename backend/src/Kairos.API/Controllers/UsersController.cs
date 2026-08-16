using System.Security.Claims;
using Kairos.Application.Common.Interfaces;
using Kairos.Application.Features.Users.Commands.UpdateProfile;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace Kairos.API.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class UsersController(IApplicationDbContext db, IMediator mediator) : ControllerBase
{
    private int GetUserId() => int.Parse(
        User.FindFirstValue(ClaimTypes.NameIdentifier)
        ?? User.FindFirstValue("sub")
        ?? throw new UnauthorizedAccessException());

    /// <summary>
    /// Perfil propio con sus métricas reales: publicaciones, seguidores,
    /// seguidos y competencias declaradas.
    ///
    /// Antes la aplicación solo conocía lo que vino en la respuesta del login,
    /// así que la pantalla de perfil mostraba cero conexiones para todo el mundo.
    /// </summary>
    [HttpGet("me")]
    public async Task<IActionResult> GetMyProfile(CancellationToken ct)
    {
        var userId = GetUserId();

        var profile = await db.Users
            .Where(u => u.Id == userId)
            .Select(u => new
            {
                u.Id,
                u.Username,
                u.Email,
                u.FullName,
                u.Bio,
                u.Institution,
                u.ProfilePictureUrl,
                u.Role,
                u.Status,
                u.QuickMatchVisible,
                u.CreatedAt,
                PostCount      = u.Posts.Count,
                SkillCount     = u.Skills.Count,
                FollowingCount = db.Follows.Count(f => f.FollowerId == userId),
                FollowerCount  = db.Follows.Count(f => f.FollowedId == userId),
            })
            .FirstOrDefaultAsync(ct);

        return profile is null ? NotFound() : Ok(profile);
    }

    /// <summary>Actualiza el perfil propio.</summary>
    [HttpPut("me")]
    [ProducesResponseType(typeof(UserProfileDto), StatusCodes.Status200OK)]
    public async Task<IActionResult> UpdateMyProfile(
        [FromBody] UpdateProfileRequest request,
        CancellationToken ct)
    {
        var result = await mediator.Send(
            new UpdateProfileCommand(
                GetUserId(),
                request.FullName,
                request.Bio,
                request.Institution,
                request.ProfilePictureUrl),
            ct);

        return Ok(result);
    }
}

public record UpdateProfileRequest(
    string  FullName,
    string? Bio               = null,
    string? Institution       = null,
    string? ProfilePictureUrl = null);
