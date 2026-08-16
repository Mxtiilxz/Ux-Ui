using Kairos.Application.Common.Interfaces;
using Kairos.Domain.Entities;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace Kairos.Application.Features.Staff.Commands.CreateAccount;

public class CreateAccountCommandHandler(IApplicationDbContext db)
    : IRequestHandler<CreateAccountCommand, CreateAccountResult>
{
    public async Task<CreateAccountResult> Handle(CreateAccountCommand request, CancellationToken cancellationToken)
    {
        var email = request.Email.Trim();

        if (await db.Users.AnyAsync(u => u.Email == email, cancellationToken))
            throw new InvalidOperationException($"El correo {email} ya está registrado.");

        // En una importación de curso completo los nombres de usuario chocan con
        // facilidad, así que se desambigua en vez de abortar la fila.
        var username = request.Username.Trim();
        if (await db.Users.AnyAsync(u => u.Username == username, cancellationToken))
            username = $"{username}_{Guid.NewGuid().ToString("N")[..4]}";

        var role = request.Role.ToLowerInvariant();

        var user = new User
        {
            Username     = username,
            Email        = email,
            PasswordHash = BCrypt.Net.BCrypt.HashPassword(request.Password),
            FullName     = request.FullName.Trim(),
            Institution  = request.Institution,
            Role         = role,
            Status       = "approved",
        };

        db.Users.Add(user);
        await db.SaveChangesAsync(cancellationToken);

        return new CreateAccountResult(user.Id, user.Email, user.Username, user.Role);
    }
}
