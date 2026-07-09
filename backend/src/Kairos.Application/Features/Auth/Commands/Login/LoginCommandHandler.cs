using Kairos.Application.Common.Interfaces;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace Kairos.Application.Features.Auth.Commands.Login;

public class LoginCommandHandler(IApplicationDbContext db, IJwtService jwtService)
    : IRequestHandler<LoginCommand, LoginResult>
{
    public async Task<LoginResult> Handle(LoginCommand request, CancellationToken cancellationToken)
    {
        var user = await db.Users
            .FirstOrDefaultAsync(u => u.Email == request.Email, cancellationToken)
            ?? throw new UnauthorizedAccessException("Credenciales inválidas.");

        if (!BCrypt.Net.BCrypt.Verify(request.Password, user.PasswordHash))
            throw new UnauthorizedAccessException("Credenciales inválidas.");

        if (user.Status == "pending")
            throw new UnauthorizedAccessException("Tu cuenta está pendiente de aprobación por el staff del liceo.");

        if (user.Status == "rejected")
            throw new UnauthorizedAccessException("Tu cuenta fue rechazada. Contacta al staff del liceo.");

        var token = jwtService.GenerateToken(user);
        return new LoginResult(user.Id, token, user.FullName, user.ProfilePictureUrl, user.Role, user.Institution, user.QuickMatchVisible);
    }
}
