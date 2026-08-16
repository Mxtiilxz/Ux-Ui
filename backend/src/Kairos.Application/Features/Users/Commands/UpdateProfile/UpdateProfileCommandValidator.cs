using FluentValidation;

namespace Kairos.Application.Features.Users.Commands.UpdateProfile;

public class UpdateProfileCommandValidator : AbstractValidator<UpdateProfileCommand>
{
    public UpdateProfileCommandValidator()
    {
        RuleFor(x => x.FullName)
            .NotEmpty().WithMessage("El nombre no puede quedar vacío.")
            .MaximumLength(120);

        // Los límites son los de las columnas: si se superan, el error llegaría
        // desde la base de datos como un fallo interno en vez de un aviso claro.
        RuleFor(x => x.Bio).MaximumLength(500)
            .WithMessage("La descripción no puede superar los 500 caracteres.");

        RuleFor(x => x.Institution).MaximumLength(200);

        RuleFor(x => x.ProfilePictureUrl).MaximumLength(500);
    }
}
