using FluentValidation;

namespace Kairos.Application.Features.Matching.Commands.CreateSkill;

public class CreateSkillCommandValidator : AbstractValidator<CreateSkillCommand>
{
    public CreateSkillCommandValidator()
    {
        RuleFor(x => x.Name)
            .NotEmpty().WithMessage("El nombre de la competencia no puede estar vacío.")
            .MaximumLength(80).WithMessage("El nombre no puede superar los 80 caracteres.");

        RuleFor(x => x.Category)
            .NotEmpty().WithMessage("La categoría es obligatoria.");
    }
}
