using MediatR;

namespace Kairos.Application.Features.Auth.Commands.Register;

/// <summary>
/// Registro público. Solo alumnos y empresas: el rol <c>staff</c> se crea desde
/// el panel del liceo.
///
/// El nombre de usuario ya no viaja en la petición. Antes lo elegía quien se
/// registraba, lo que dejaba al liceo sin control sobre cómo aparecen sus
/// alumnos; ahora se deriva del nombre real en el servidor.
/// </summary>
public record RegisterCommand(
    string  Email,
    string  Password,
    string? Role,
    /// <summary>Nombres del alumno. Vacío para una empresa.</summary>
    string? FirstNames  = null,
    /// <summary>Apellidos del alumno. Vacío para una empresa.</summary>
    string? LastNames   = null,
    /// <summary>Razón social. Solo para una empresa.</summary>
    string? CompanyName = null,
    string? Institution = null) : IRequest<RegisterResult>;

public record RegisterResult(
    int    UserId,
    string Email,
    string Username,
    string FullName,
    /// <summary>"pending" para un alumno, "approved" para una empresa.</summary>
    string Status);
