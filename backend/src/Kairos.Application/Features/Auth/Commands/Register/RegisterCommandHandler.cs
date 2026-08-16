using Kairos.Application.Common.Interfaces;
using Kairos.Application.Common.Validation;
using Kairos.Domain.Entities;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace Kairos.Application.Features.Auth.Commands.Register;

public class RegisterCommandHandler(IApplicationDbContext db)
    : IRequestHandler<RegisterCommand, RegisterResult>
{
    public async Task<RegisterResult> Handle(RegisterCommand request, CancellationToken cancellationToken)
    {
        var email = request.Email.Trim();

        if (await db.Users.AnyAsync(u => u.Email == email, cancellationToken))
            throw new InvalidOperationException("El correo ya está registrado.");

        // El rol llega en el cuerpo de la petición, así que no se puede confiar
        // en él aunque el validador ya lo haya revisado: el endpoint es
        // alcanzable sin pasar por la aplicación. Se acepta "company" y todo lo
        // demás cae a "student"; "staff" nunca se concede por esta vía.
        var isCompany = string.Equals(request.Role, "company", StringComparison.OrdinalIgnoreCase);

        var fullName = isCompany
            ? request.CompanyName!.Trim()
            : $"{request.FirstNames!.Trim()} {request.LastNames!.Trim()}";

        var username = isCompany
            ? UsernameBuilder.ForCompany(fullName)
            : UsernameBuilder.ForPerson(request.FirstNames!, request.LastNames!);

        username = await MakeUniqueAsync(username, cancellationToken);

        // Una empresa entra directo: es externa al liceo y su aprobación no
        // aporta nada que la moderación posterior no pueda resolver. Un alumno
        // queda pendiente, porque su cuenta lo acredita como parte del liceo.
        var status = isCompany ? "approved" : "pending";

        var user = new User
        {
            Username     = username,
            Email        = email,
            PasswordHash = BCrypt.Net.BCrypt.HashPassword(request.Password),
            FullName     = fullName,
            Institution  = request.Institution?.Trim(),
            Role         = isCompany ? "company" : "student",
            Status       = status,
            // Una empresa se une en el momento del registro; un alumno, cuando
            // el liceo lo aprueba. El historial de altas lee esta fecha.
            ApprovedAt   = isCompany ? DateTime.UtcNow : null,
        };

        db.Users.Add(user);
        await db.SaveChangesAsync(cancellationToken);

        return new RegisterResult(user.Id, user.Email, user.Username, user.FullName, user.Status);
    }

    /// <summary>
    /// Dos alumnos pueden llamarse igual, así que al chocar se agrega un número
    /// en vez de rechazar el registro.
    /// </summary>
    private async Task<string> MakeUniqueAsync(string username, CancellationToken cancellationToken)
    {
        if (!await db.Users.AnyAsync(u => u.Username == username, cancellationToken))
            return username;

        for (var suffix = 2; suffix < 100; suffix++)
        {
            var candidate = $"{username}{suffix}";
            if (!await db.Users.AnyAsync(u => u.Username == candidate, cancellationToken))
                return candidate;
        }

        return $"{username}{Guid.NewGuid().ToString("N")[..6]}";
    }
}
