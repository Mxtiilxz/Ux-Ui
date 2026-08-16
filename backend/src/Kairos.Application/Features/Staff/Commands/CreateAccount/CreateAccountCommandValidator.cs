using FluentValidation;
using Kairos.Application.Common.Validation;

namespace Kairos.Application.Features.Staff.Commands.CreateAccount;

public class CreateAccountCommandValidator : AbstractValidator<CreateAccountCommand>
{
    /// <summary>
    /// Roles que el liceo puede dar de alta. Las empresas quedan fuera a
    /// propósito: se registran ellas mismas, y crearlas desde aquí dejaría una
    /// cuenta de empresa sin nadie detrás que la reclame.
    /// </summary>
    private static readonly HashSet<string> AssignableRoles =
        new(StringComparer.OrdinalIgnoreCase) { "student", "staff" };

    public CreateAccountCommandValidator()
    {
        RuleFor(x => x.FullName).NotEmpty().MaximumLength(120);

        RuleFor(x => x.Username).NotEmpty().MaximumLength(50);

        RuleFor(x => x.Role)
            .Must(AssignableRoles.Contains)
            .WithMessage("El rol debe ser 'student' o 'staff'.");

        RuleFor(x => x.Email)
            .NotEmpty()
            .EmailAddress()
            .Must(AccountRules.IsInstitutional)
            .WithMessage(
                $"Las cuentas de alumno y de personal deben usar un correo " +
                $"{AccountRules.InstitutionalDomain}.");

        RuleFor(x => x.Password).ApplyPasswordPolicy();
    }
}
