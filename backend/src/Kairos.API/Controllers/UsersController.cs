using System.Security.Claims;
using Kairos.Application.Common.Interfaces;
using Kairos.Application.Features.Users.Commands.UpdateProfile;
using Kairos.Domain.Entities;
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
                PostCount  = u.Posts.Count,
                SkillCount = u.Skills.Count,
                // Una conexión aceptada cuenta en los dos sentidos, así que se
                // miran ambos lados de la fila. Contar solo un lado devolvería
                // la mitad de los contactos según quién envió la solicitud.
                ConnectionCount = db.Follows.Count(
                    f => f.Status == "accepted" &&
                         (f.FollowerId == userId || f.FollowedId == userId)),
                PendingRequestCount = db.Follows.Count(
                    f => f.FollowedId == userId && f.Status == "pending"),
            })
            .FirstOrDefaultAsync(ct);

        return profile is null ? NotFound() : Ok(profile);
    }

    /// <summary>Preferencias de privacidad propias.</summary>
    [HttpGet("me/privacy")]
    public async Task<IActionResult> GetMyPrivacy(CancellationToken ct)
    {
        var userId = GetUserId();
        var privacy = await db.Users
            .Where(u => u.Id == userId)
            .Select(u => new { u.MessagePrivacy, u.PostVisibility })
            .FirstOrDefaultAsync(ct);

        return privacy is null ? NotFound() : Ok(privacy);
    }

    /// <summary>
    /// Cambia quién puede escribirle y quién ve sus publicaciones.
    ///
    /// Un valor desconocido se rechaza en vez de caer en un valor por defecto:
    /// dejar pasar "publico" por error y guardarlo como "solo contactos" —o al
    /// revés— sería exponer o esconder contenido sin que el usuario lo sepa.
    /// </summary>
    [HttpPut("me/privacy")]
    public async Task<IActionResult> UpdateMyPrivacy(
        [FromBody] UpdatePrivacyRequest request,
        CancellationToken ct)
    {
        if (!PrivacyAudience.IsValidForMessages(request.MessagePrivacy))
            return BadRequest(new { detail = "Audiencia de mensajes no válida." });

        if (!PrivacyAudience.IsValidForPosts(request.PostVisibility))
            return BadRequest(new { detail = "Audiencia de publicaciones no válida." });

        var userId = GetUserId();
        var user = await db.Users.FirstOrDefaultAsync(u => u.Id == userId, ct);
        if (user is null) return NotFound();

        user.MessagePrivacy = request.MessagePrivacy;
        user.PostVisibility = request.PostVisibility;
        await db.SaveChangesAsync(ct);

        return Ok(new { user.MessagePrivacy, user.PostVisibility });
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

public record UpdatePrivacyRequest(string MessagePrivacy, string PostVisibility);

public record UpdateProfileRequest(
    string  FullName,
    string? Bio               = null,
    string? Institution       = null,
    string? ProfilePictureUrl = null);
