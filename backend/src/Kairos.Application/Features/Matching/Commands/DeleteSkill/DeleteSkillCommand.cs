using MediatR;

namespace Kairos.Application.Features.Matching.Commands.DeleteSkill;

/// <summary>
/// Quita una competencia del catálogo. Solo el personal del liceo, y solo si
/// ningún alumno la tiene registrada.
/// </summary>
public record DeleteSkillCommand(int SkillId) : IRequest;
