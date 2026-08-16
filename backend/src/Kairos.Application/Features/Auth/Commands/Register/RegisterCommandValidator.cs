using FluentValidation;
using Kairos.Application.Common.Validation;

namespace Kairos.Application.Features.Auth.Commands.Register;

public class RegisterCommandValidator : AbstractValidator<RegisterCommand>
{
    /// <summary>
    /// Roles que se pueden pedir desde el registro público.
    /// <c>staff</c> queda deliberadamente fuera: es el rol que aprueba cuentas y
    /// administra a los demás usuarios, así que no puede concederse a quien lo
    /// pida. Las cuentas de personal se crean desde el panel de administración,
    /// autenticado como staff (<c>POST /api/staff/users</c>).
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

        // Los alumnos usan el correo institucional; una empresa externa, el suyo.
        RuleFor(x => x.Email)
            .Must(AccountRules.IsInstitutional)
            .When(x => !string.Equals(x.Role, "company", StringComparison.OrdinalIgnoreCase))
            .WithMessage($"El correo del estudiante debe terminar en {AccountRules.InstitutionalDomain}.");

        RuleFor(x => x.Password).ApplyPasswordPolicy();
    }
}
