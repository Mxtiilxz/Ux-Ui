using Kairos.Application.Common.Exceptions;
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

        // Estas dos no son un fallo de credenciales: la contraseña era correcta.
        // Van con su propio tipo para que la aplicación pueda mostrar la pantalla
        // de espera en vez de un error de acceso.
        if (user.Status == "pending")
            throw new AccountNotApprovedException(
                "pending",
                "Tu cuenta está pendiente de aprobación por el personal del liceo.");

        if (user.Status == "rejected")
            throw new AccountNotApprovedException(
                "rejected",
                "Tu cuenta fue rechazada. Contacta al personal del liceo.");

        var token = jwtService.GenerateToken(user);
        return new LoginResult(user.Id, token, user.FullName, user.ProfilePictureUrl, user.Role, user.Institution, user.QuickMatchVisible);
    }
}
