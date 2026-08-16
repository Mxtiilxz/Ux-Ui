using MediatR;

namespace Kairos.Application.Features.Users.Commands.UpdateProfile;

/// <summary>
/// Actualiza el perfil propio.
///
/// No existía: el botón "Editar perfil" estaba en la interfaz desde el
/// prototipo, pero no había endpoint detrás, así que un usuario no podía
/// cambiar su descripción ni su foto una vez creada la cuenta.
///
/// Deja fuera a propósito el correo, el nombre de usuario y el rol: son la
/// identidad de la cuenta y cambiarlos corresponde al liceo, no al usuario.
/// </summary>
public record UpdateProfileCommand(
    int     UserId,
    string  FullName,
    string? Bio,
    string? Institution,
    string? ProfilePictureUrl) : IRequest<UserProfileDto>;

public record UserProfileDto(
    int     Id,
    string  Username,
    string  Email,
    string  FullName,
    string? Bio,
    string? Institution,
    string? ProfilePictureUrl,
    string? Role,
    string  Status,
    bool    QuickMatchVisible);
