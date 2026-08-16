using Kairos.Application.Common.Interfaces;
using Kairos.Domain.Entities;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace Kairos.Application.Features.Auth.Commands.Register;

public class RegisterCommandHandler(IApplicationDbContext db)
    : IRequestHandler<RegisterCommand, RegisterResult>
{
    public async Task<RegisterResult> Handle(RegisterCommand request, CancellationToken cancellationToken)
    {
        var emailExists = await db.Users.AnyAsync(u => u.Email == request.Email, cancellationToken);
        if (emailExists) throw new InvalidOperationException("El correo ya está registrado.");

        var usernameExists = await db.Users.AnyAsync(u => u.Username == request.Username, cancellationToken);
        if (usernameExists) throw new InvalidOperationException("El nombre de usuario ya está en uso.");

        // El rol llega en el cuerpo de la petición, así que no se puede confiar en
        // él aunque el validador ya lo haya revisado: cualquiera puede llamar al
        // endpoint sin pasar por la aplicación. Se acepta "company" y todo lo
        // demás cae a "student"; "staff" nunca se concede por esta vía.
        var role = string.Equals(request.Role, "company", StringComparison.OrdinalIgnoreCase)
            ? "company"
            : "student";

        var user = new User
        {
            Username = request.Username,
            Email = request.Email,
            PasswordHash = BCrypt.Net.BCrypt.HashPassword(request.Password),
            FullName = request.FullName,
            Institution = request.Institution,
            Role = role,
            Status = "pending"
        };

        db.Users.Add(user);
        await db.SaveChangesAsync(cancellationToken);

        return new RegisterResult(user.Id, user.Email);
    }
}
