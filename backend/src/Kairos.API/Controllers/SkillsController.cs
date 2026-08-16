using System.Security.Claims;
using Kairos.Application.Common.Interfaces;
using Kairos.Application.Features.Matching.Commands.AddUserSkill;
using Kairos.Application.Features.Matching.Commands.CreateSkill;
using Kairos.Application.Features.Matching.Commands.DeleteSkill;
using Kairos.Application.Features.Matching.Commands.RemoveUserSkill;
using Kairos.Application.Features.Matching.Commands.SetQuickMatchTemplate;
using Kairos.Application.Features.Matching.Commands.SetQuickMatchVisibility;
using Kairos.Application.Features.Matching.Queries.GetMySkills;
using Kairos.Application.Features.Matching.Queries.GetQuickMatchTemplate;
using Kairos.Application.Features.Matching.Queries.SearchCandidates;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.EntityFrameworkCore;

namespace Kairos.API.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class SkillsController(IMediator mediator, IApplicationDbContext db) : ControllerBase
{
    private int GetUserId() => int.Parse(
        User.FindFirstValue(ClaimTypes.NameIdentifier)
        ?? User.FindFirstValue("sub")
        ?? throw new UnauthorizedAccessException());

    private string GetRole() => User.FindFirstValue(ClaimTypes.Role) ?? "student";

    /// <summary>Catálogo completo de competencias, para selectores de perfil y de búsqueda.</summary>
    [HttpGet]
    public async Task<IActionResult> GetSkills(CancellationToken ct)
    {
        var skills = await db.Skills
            .OrderBy(s => s.Category)
            .ThenBy(s => s.Name)
            .Select(s => new { s.Id, s.Name, Category = s.Category.ToString() })
            .ToListAsync(ct);

        return Ok(skills);
    }

    /// <summary>
    /// Catálogo con el número de alumnos que tiene cada competencia (solo staff).
    /// El recuento es lo que permite al liceo ver qué competencias sobran y cuáles
    /// faltan, en vez de administrar la lista a ciegas.
    /// </summary>
    [HttpGet("catalog")]
    public async Task<IActionResult> GetCatalog(CancellationToken ct)
    {
        if (GetRole() != "staff") return Forbid();

        var catalog = await db.Skills
            .OrderBy(s => s.Category)
            .ThenBy(s => s.Name)
            .Select(s => new SkillCatalogItem(
                s.Id,
                s.Name,
                s.Category.ToString(),
                s.UserSkills.Count))
            .ToListAsync(ct);

        return Ok(catalog);
    }

    /// <summary>Agrega una competencia al catálogo (solo staff).</summary>
    [HttpPost]
    public async Task<IActionResult> CreateSkill([FromBody] CreateSkillRequest request, CancellationToken ct)
    {
        if (GetRole() != "staff") return Forbid();

        var created = await mediator.Send(new CreateSkillCommand(request.Name, request.Category), ct);
        return CreatedAtAction(nameof(GetSkills), new { id = created.Id }, created);
    }

    /// <summary>Quita una competencia del catálogo, si ningún alumno la tiene (solo staff).</summary>
    [HttpDelete("{skillId:int}")]
    public async Task<IActionResult> DeleteSkill(int skillId, CancellationToken ct)
    {
        if (GetRole() != "staff") return Forbid();

        await mediator.Send(new DeleteSkillCommand(skillId), ct);
        return NoContent();
    }

    /// <summary>Quick Match: candidatos rankeados por coincidencia de competencias (solo empresas).</summary>
    [HttpGet("candidates")]
    [EnableRateLimiting("quickmatch-search")]
    public async Task<IActionResult> SearchCandidates([FromQuery] string skillIds, CancellationToken ct)
    {
        if (GetRole() != "company") return Forbid();

        var ids = (skillIds ?? string.Empty)
            .Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
            .Select(s => int.TryParse(s, out var id) ? id : (int?)null)
            .Where(id => id.HasValue)
            .Select(id => id!.Value)
            .ToList();

        var result = await mediator.Send(new SearchCandidatesQuery(ids), ct);
        return Ok(result);
    }

    /// <summary>Activa/desactiva la visibilidad propia en las búsquedas de Quick Match (solo estudiantes).</summary>
    [HttpPut("me/visibility")]
    public async Task<IActionResult> SetVisibility([FromBody] SetVisibilityRequest request, CancellationToken ct)
    {
        var visible = await mediator.Send(new SetQuickMatchVisibilityCommand(GetUserId(), request.Visible), ct);
        return Ok(new { visible });
    }

    /// <summary>IDs de las competencias que el usuario autenticado ya tiene registradas.</summary>
    [HttpGet("me")]
    public async Task<IActionResult> GetMySkills(CancellationToken ct)
    {
        var ids = await mediator.Send(new GetMySkillsQuery(GetUserId()), ct);
        return Ok(ids);
    }

    /// <summary>Agrega una competencia al perfil propio (solo estudiantes).</summary>
    [HttpPost("me/{skillId:int}")]
    public async Task<IActionResult> AddMySkill(int skillId, CancellationToken ct)
    {
        await mediator.Send(new AddUserSkillCommand(GetUserId(), skillId), ct);
        return NoContent();
    }

    /// <summary>Quita una competencia del perfil propio.</summary>
    [HttpDelete("me/{skillId:int}")]
    public async Task<IActionResult> RemoveMySkill(int skillId, CancellationToken ct)
    {
        await mediator.Send(new RemoveUserSkillCommand(GetUserId(), skillId), ct);
        return NoContent();
    }

    /// <summary>Plantilla de mensaje que la empresa usa para contactar candidatos en Quick Match (solo empresas).</summary>
    [HttpGet("company/message")]
    public async Task<IActionResult> GetCompanyMessage(CancellationToken ct)
    {
        if (GetRole() != "company") return Forbid();

        var result = await mediator.Send(new GetQuickMatchTemplateQuery(GetUserId()), ct);
        return Ok(result);
    }

    /// <summary>Actualiza la plantilla de contacto de la empresa. Enviar vacío restablece el mensaje por defecto (solo empresas).</summary>
    [HttpPut("company/message")]
    public async Task<IActionResult> SetCompanyMessage([FromBody] SetCompanyMessageRequest request, CancellationToken ct)
    {
        if (GetRole() != "company") return Forbid();

        var result = await mediator.Send(new SetQuickMatchTemplateCommand(GetUserId(), request.Template), ct);
        return Ok(result);
    }
}

public record SetVisibilityRequest(bool Visible);
public record SetCompanyMessageRequest(string? Template);
public record CreateSkillRequest(string Name, string Category);
