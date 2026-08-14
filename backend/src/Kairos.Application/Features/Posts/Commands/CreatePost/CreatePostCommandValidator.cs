using FluentValidation;

namespace Kairos.Application.Features.Posts.Commands.CreatePost;

public class CreatePostCommandValidator : AbstractValidator<CreatePostCommand>
{
    private static readonly HashSet<string> ValidTypes =
        new(StringComparer.OrdinalIgnoreCase) { "general", "event", "job" };

    public CreatePostCommandValidator()
    {
        RuleFor(x => x.Content)
            .NotEmpty().WithMessage("El contenido no puede estar vacío.")
            .MaximumLength(2000).WithMessage("El contenido no puede superar los 2000 caracteres.");

        RuleFor(x => x.ImageAltText)
            .MaximumLength(300)
            .WithMessage("La descripción de la imagen no puede superar los 300 caracteres.");

        RuleFor(x => x.PostType)
            .Must(t => ValidTypes.Contains(t))
            .WithMessage("El tipo debe ser 'general', 'event' o 'job'.");

        // EventDate is required for event posts
        RuleFor(x => x.EventDate)
            .NotEmpty()
            .WithMessage("La fecha del evento es obligatoria para publicaciones de tipo 'event'.")
            .When(x => string.Equals(x.PostType, "event", StringComparison.OrdinalIgnoreCase));
    }
}
