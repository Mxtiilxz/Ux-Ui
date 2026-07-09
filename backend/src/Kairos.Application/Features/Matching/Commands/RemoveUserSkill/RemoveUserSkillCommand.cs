using MediatR;

namespace Kairos.Application.Features.Matching.Commands.RemoveUserSkill;

public record RemoveUserSkillCommand(int UserId, int SkillId) : IRequest;
