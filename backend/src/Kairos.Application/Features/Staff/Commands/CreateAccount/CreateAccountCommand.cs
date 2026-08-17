using MediatR;

namespace Kairos.Application.Features.Staff.Commands.CreateAccount;

/// <summary>
/// Crea una cuenta desde el panel del liceo. Es la única vía para dar de alta
/// a un <c>staff</c>: el registro público no concede ese rol.
///
/// A diferencia del registro público, la cuenta nace <c>approved</c> — no tiene
/// sentido que el liceo cree una cuenta y luego tenga que aprobársela a sí mismo.
/// </summary>
public record CreateAccountCommand(
    string  FullName,
    string  Email,
    string  Username,
    string  Password,
    string  Role,
    string? Institution,
    /// <summary>
    /// Especialidad que cursa el alumno. Viene de la columna del CSV que el
    /// liceo ya rellenaba y que hasta ahora se descartaba al importar. Con ella
    /// se crea la entrada de formación de su currículum.
    /// </summary>
    string? Specialty = null) : IRequest<CreateAccountResult>;

public record CreateAccountResult(int UserId, string Email, string Username, string Role);
