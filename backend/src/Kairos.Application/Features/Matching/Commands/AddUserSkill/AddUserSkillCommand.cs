using MediatR;

namespace Kairos.Application.Features.Matching.Commands.AddUserSkill;

public record AddUserSkillCommand(int UserId, int SkillId) : IRequest;
