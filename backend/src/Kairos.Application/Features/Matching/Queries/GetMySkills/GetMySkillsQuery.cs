using MediatR;

namespace Kairos.Application.Features.Matching.Queries.GetMySkills;

public record GetMySkillsQuery(int UserId) : IRequest<IReadOnlyList<int>>;
