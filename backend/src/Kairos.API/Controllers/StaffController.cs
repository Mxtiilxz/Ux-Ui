using System.Security.Claims;
using Kairos.Application.Common.Interfaces;
using Kairos.Application.Features.Staff.Commands.CreateAccount;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace Kairos.API.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class StaffController(IApplicationDbContext db, IMediator mediator) : ControllerBase
{
    private string GetRole() =>
        User.FindFirstValue(ClaimTypes.Role) ?? "student";

    /// <summary>
    /// Crea una cuenta de alumno o de personal (solo staff).
    ///
    /// Es la única vía para dar de alta a un <c>staff</c>: el registro público
    /// no concede ese rol, así que el primer administrador lo crea
    /// <c>ProductionSeeder</c> y los siguientes se crean desde aquí. También es
    /// el endpoint que usa la importación CSV de cursos.
    /// </summary>
    [HttpPost("users")]
    [ProducesResponseType(typeof(CreateAccountResult), StatusCodes.Status201Created)]
    [ProducesResponseType(StatusCodes.Status409Conflict)]
    public async Task<IActionResult> CreateAccount(
        [FromBody] CreateAccountRequest request,
        CancellationToken ct)
    {
        if (GetRole() != "staff") return Forbid();

        var result = await mediator.Send(
            new CreateAccountCommand(
                request.FullName,
                request.Email,
                request.Username,
                request.Password,
                request.Role,
                request.Institution),
            ct);

        return CreatedAtAction(nameof(GetAllUsers), result);
    }

    /// <summary>List users pending approval.</summary>
    [HttpGet("registration-requests")]
    public async Task<IActionResult> GetPendingRegistrations(CancellationToken ct)
    {
        if (GetRole() != "staff") return Forbid();

        var pending = await db.Users
            .Where(u => u.Status == "pending")
            .OrderBy(u => u.CreatedAt)
            .Select(u => new
            {
                u.Id,
                u.FullName,
                u.Email,
                u.Username,
                u.Role,
                u.Institution,
                u.CreatedAt,
            })
            .ToListAsync(ct);

        return Ok(pending);
    }

    /// <summary>Approve a pending user account.</summary>
    [HttpPost("users/{id:int}/approve")]
    public async Task<IActionResult> ApproveUser(int id, CancellationToken ct)
    {
        if (GetRole() != "staff") return Forbid();

        var user = await db.Users.FindAsync([id], ct);
        if (user is null) return NotFound();

        user.Status = "approved";
        // Se registra el momento de la aprobación: es cuando el alumno pasa a
        // formar parte de la red, y es lo que ordena el historial de altas.
        user.ApprovedAt ??= DateTime.UtcNow;
        await db.SaveChangesAsync(ct);
        return NoContent();
    }

    /// <summary>Reject a pending user account.</summary>
    [HttpPost("users/{id:int}/reject")]
    public async Task<IActionResult> RejectUser(int id, CancellationToken ct)
    {
        if (GetRole() != "staff") return Forbid();

        var user = await db.Users.FindAsync([id], ct);
        if (user is null) return NotFound();

        user.Status = "rejected";
        await db.SaveChangesAsync(ct);
        return NoContent();
    }

    /// <summary>Permanently delete any user account (staff only).</summary>
    [HttpDelete("users/{id:int}")]
    public async Task<IActionResult> DeleteUser(int id, CancellationToken ct)
    {
        if (GetRole() != "staff") return Forbid();

        var user = await db.Users.FindAsync([id], ct);
        if (user is null) return NotFound();

        db.Users.Remove(user);
        await db.SaveChangesAsync(ct);
        return NoContent();
    }

    /// <summary>
    /// Historial de altas: quién se sumó a la plataforma y cuándo.
    ///
    /// Un alumno aparece al ser aprobado, no al registrarse — antes de eso no
    /// forma parte de la red y anunciarlo sería prematuro. Una empresa aparece
    /// al registrarse, porque entra directo.
    /// </summary>
    [HttpGet("join-history")]
    public async Task<IActionResult> GetJoinHistory(
        [FromQuery] int limit = 30,
        CancellationToken ct = default)
    {
        if (GetRole() != "staff") return Forbid();

        var history = await db.Users
            .Where(u => u.Status == "approved" && u.ApprovedAt != null)
            .OrderByDescending(u => u.ApprovedAt)
            .Take(Math.Clamp(limit, 1, 100))
            .Select(u => new
            {
                u.Id,
                u.FullName,
                u.Username,
                u.Role,
                u.Institution,
                JoinedAt = u.ApprovedAt,
            })
            .ToListAsync(ct);

        return Ok(history);
    }

    /// <summary>Número de solicitudes pendientes, para la insignia del panel.</summary>
    [HttpGet("pending-count")]
    public async Task<IActionResult> GetPendingCount(CancellationToken ct)
    {
        if (GetRole() != "staff") return Forbid();

        var count = await db.Users.CountAsync(u => u.Status == "pending", ct);
        return Ok(new { count });
    }

    /// <summary>List all registered users (for staff dashboard).</summary>
    [HttpGet("users")]
    public async Task<IActionResult> GetAllUsers(CancellationToken ct)
    {
        if (GetRole() != "staff") return Forbid();

        var users = await db.Users
            .OrderBy(u => u.FullName)
            .Select(u => new
            {
                u.Id,
                u.FullName,
                u.Email,
                u.Username,
                u.Role,
                u.Institution,
                u.Status,
                u.CreatedAt,
            })
            .ToListAsync(ct);

        return Ok(users);
    }
}

public record CreateAccountRequest(
    string  FullName,
    string  Email,
    string  Username,
    string  Password,
    string  Role,
    string? Institution);
