using FluentValidation;

namespace Kairos.Application.Common.Validation;

/// <summary>
/// Reglas de cuenta compartidas por el registro público y por la creación de
/// cuentas desde el panel del liceo. Viven aquí para que endurecer una
/// contraseña no deje la otra puerta con las reglas viejas.
/// </summary>
public static class AccountRules
{
    /// <summary>Dominio institucional del liceo.</summary>
    public const string InstitutionalDomain = "@kairos.cl";

    public static bool IsInstitutional(string? email) =>
        email is not null &&
        email.Trim().EndsWith(InstitutionalDomain, StringComparison.OrdinalIgnoreCase);

    /// <summary>Mínimo 8 caracteres, con mayúscula, minúscula y carácter especial.</summary>
    public static IRuleBuilderOptions<T, string> ApplyPasswordPolicy<T>(
        this IRuleBuilder<T, string> rule) =>
        rule
            .NotEmpty().WithMessage("La contraseña es obligatoria.")
            .MinimumLength(8).WithMessage("La contraseña debe tener al menos 8 caracteres.")
            .Matches("[A-ZÁÉÍÓÚÑ]").WithMessage("La contraseña debe incluir al menos una mayúscula.")
            .Matches("[a-záéíóúñ]").WithMessage("La contraseña debe incluir al menos una minúscula.")
            .Matches(@"[^\w\s]").WithMessage("La contraseña debe incluir al menos un carácter especial.");
}
