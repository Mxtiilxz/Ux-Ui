using MediatR;

namespace Kairos.Application.Features.Auth.Commands.Login;

public record LoginCommand(string Email, string Password) : IRequest<LoginResult>;

public record LoginResult(int UserId, string Token, string FullName, string? ProfilePictureUrl, string? Role, string? Institution, bool QuickMatchVisible);
