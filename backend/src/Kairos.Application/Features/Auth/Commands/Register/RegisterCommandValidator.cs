using FluentValidation;
using Kairos.Application.Common.Validation;

namespace Kairos.Application.Features.Auth.Commands.Register;

public class RegisterCommandValidator : AbstractValidator<RegisterCommand>
{
    /// <summary>
    /// Roles que se pueden pedir desde el registro público.
    /// <c>staff</c> queda deliberadamente fuera: es el rol que aprueba cuentas y
    /// administra a los demás usuarios, así que no puede concederse a quien lo
    /// pida. Las cuentas de personal se crean desde el panel de administración
    /// (<c>POST /api/staff/users</c>).
    /// </summary>
    private static readonly HashSet<string> SelfServiceRoles =
        new(StringComparer.OrdinalIgnoreCase) { "student", "company" };

    public RegisterCommandValidator()
    {
        RuleFor(x => x.Role)
            .Must(role => role is null || SelfServiceRoles.Contains(role))
            .WithMessage(
                "Solo se puede registrar una cuenta de estudiante o de empresa. " +
                "Las cuentas de personal las crea el liceo.");

        RuleFor(x => x.Email).NotEmpty().EmailAddress();

        RuleFor(x => x.Password).ApplyPasswordPolicy();

        // ── Alumno ───────────────────────────────────────────────────────────
        When(x => !IsCompany(x.Role), () =>
        {
            RuleFor(x => x.FirstNames)
                .NotEmpty().WithMessage("Los nombres son obligatorios.")
                .MaximumLength(60);

            RuleFor(x => x.LastNames)
                .NotEmpty().WithMessage("Los apellidos son obligatorios.")
                .MaximumLength(60);

            RuleFor(x => x.Email)
                .Must(AccountRules.IsInstitutional)
                .WithMessage($"El correo del estudiante debe terminar en {AccountRules.InstitutionalDomain}.");
        });

        // ── Empresa ──────────────────────────────────────────────────────────
        // Usa su propio correo y su razón social; no se le piden nombres ni
        // apellidos porque no es una persona.
        When(x => IsCompany(x.Role), () =>
        {
            RuleFor(x => x.CompanyName)
                .NotEmpty().WithMessage("El nombre de la empresa es obligatorio.")
                .MaximumLength(120);
        });
    }

    private static bool IsCompany(string? role) =>
        string.Equals(role, "company", StringComparison.OrdinalIgnoreCase);
}
