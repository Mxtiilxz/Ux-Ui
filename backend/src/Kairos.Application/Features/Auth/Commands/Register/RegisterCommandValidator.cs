using FluentValidation;

namespace Kairos.Application.Features.Auth.Commands.Register;

public class RegisterCommandValidator : AbstractValidator<RegisterCommand>
{
    /// <summary>Dominio institucional del liceo.</summary>
    public const string InstitutionalDomain = "@kairos.cl";

    /// <summary>
    /// Roles que se pueden pedir desde el registro público.
    /// <c>staff</c> queda deliberadamente fuera: es el rol que aprueba cuentas y
    /// administra a los demás usuarios, así que no puede concederse a quien lo
    /// pida. Las cuentas de personal se crean desde el panel de administración.
    /// </summary>
    private static readonly HashSet<string> SelfServiceRoles =
        new(StringComparer.OrdinalIgnoreCase) { "student", "company" };

    public RegisterCommandValidator()
    {
        RuleFor(x => x.Username).NotEmpty().MaximumLength(50);

        RuleFor(x => x.FullName).NotEmpty().MaximumLength(120);

        RuleFor(x => x.Role)
            .Must(role => role is null || SelfServiceRoles.Contains(role))
            .WithMessage(
                "Solo se puede registrar una cuenta de estudiante o de empresa. " +
                "Las cuentas de personal las crea el liceo.");

        RuleFor(x => x.Email)
            .NotEmpty()
            .EmailAddress();

        // Alumnos y personal usan el correo institucional; una empresa externa,
        // el suyo propio. Se comprueba sobre el rol pedido, no sobre el asignado,
        // para que el mensaje de error llegue antes de crear nada.
        RuleFor(x => x.Email)
            .Must(email => email is not null &&
                           email.Trim().EndsWith(InstitutionalDomain, StringComparison.OrdinalIgnoreCase))
            .When(x => !string.Equals(x.Role, "company", StringComparison.OrdinalIgnoreCase))
            .WithMessage($"El correo del estudiante debe terminar en {InstitutionalDomain}.");

        RuleFor(x => x.Password)
            .NotEmpty().WithMessage("La contraseña es obligatoria.")
            .MinimumLength(8).WithMessage("La contraseña debe tener al menos 8 caracteres.")
            .Matches("[A-ZÁÉÍÓÚÑ]").WithMessage("La contraseña debe incluir al menos una mayúscula.")
            .Matches("[a-záéíóúñ]").WithMessage("La contraseña debe incluir al menos una minúscula.")
            .Matches(@"[^\w\s]").WithMessage("La contraseña debe incluir al menos un carácter especial.");
    }
}
