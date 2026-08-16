using Kairos.Application.Common.Interfaces;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace Kairos.Application.Features.Users.Commands.UpdateProfile;

public class UpdateProfileCommandHandler(IApplicationDbContext db)
    : IRequestHandler<UpdateProfileCommand, UserProfileDto>
{
    public async Task<UserProfileDto> Handle(UpdateProfileCommand request, CancellationToken cancellationToken)
    {
        var user = await db.Users
            .FirstOrDefaultAsync(u => u.Id == request.UserId, cancellationToken)
            ?? throw new KeyNotFoundException("El usuario no existe.");

        user.FullName = request.FullName.Trim();

        // Una cadena en blanco significa "borrar el campo", no "dejarlo igual":
        // si no se distinguiera, un usuario no podría vaciar su descripción.
        user.Bio               = Normalize(request.Bio);
        user.Institution       = Normalize(request.Institution);
        user.ProfilePictureUrl = Normalize(request.ProfilePictureUrl);

        await db.SaveChangesAsync(cancellationToken);

        return new UserProfileDto(
            user.Id, user.Username, user.Email, user.FullName, user.Bio,
            user.Institution, user.ProfilePictureUrl, user.Role, user.Status,
            user.QuickMatchVisible);
    }

    private static string? Normalize(string? value)
    {
        var trimmed = value?.Trim();
        return string.IsNullOrEmpty(trimmed) ? null : trimmed;
    }
}
