using MediatR;

namespace Kairos.Application.Features.Jobs.Commands.CreateJobPosting;

public record CreateJobPostingCommand(
    int      CompanyId,
    string   Title,
    string   Description,
    string?  Location,
    DateTime? ExpiresAt,
    string?  ImageUrl = null,
    /// <summary>
    /// Competencias del catálogo que la oferta solicita. Es lo que convierte la
    /// oferta en demanda medible y lo que permite cruzarla con los perfiles de
    /// los alumnos en Quick Match.
    /// </summary>
    IReadOnlyList<int>? SkillIds = null) : IRequest<int>;
