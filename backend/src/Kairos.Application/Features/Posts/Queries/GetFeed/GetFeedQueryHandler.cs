using Kairos.Application.Common.Interfaces;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace Kairos.Application.Features.Posts.Queries.GetFeed;

public class GetFeedQueryHandler(IApplicationDbContext db, IAudienceService audience)
    : IRequestHandler<GetFeedQuery, GetFeedResult>
{
    public async Task<GetFeedResult> Handle(GetFeedQuery request, CancellationToken cancellationToken)
    {
        if (request.Page < 1)
            throw new ArgumentException("El número de página debe ser mayor a 0.");

        // Cada autor decide si publica en abierto o solo para sus contactos, así
        // que el conjunto de autores visibles se calcula por lector. El filtro va
        // antes de contar: si no, la paginación prometería publicaciones que
        // luego no aparecen.
        var visibleAuthors = await audience.VisibleAuthorsAsync(request.ViewerId, cancellationToken);

        var query = db.Posts.Where(p => visibleAuthors.Contains(p.AuthorId));

        var skip  = (request.Page - 1) * request.PageSize;
        var total = await query.CountAsync(cancellationToken);

        var posts = await query
            .Include(p => p.Author)
            .OrderByDescending(p => p.CreatedAt)
            .Skip(skip)
            .Take(request.PageSize)
            .Select(p => new PostDto(
                p.Id,
                p.AuthorId,
                p.Author.FullName,
                p.Author.Role ?? "student",
                p.Author.ProfilePictureUrl,
                p.Content,
                p.Type.ToString(),
                p.ImageUrl,
                p.ImageAltText,
                p.EventDate,
                p.LikesCount,
                p.CommentsCount,
                p.CreatedAt))
            .ToListAsync(cancellationToken);

        return new GetFeedResult(posts, total, skip + posts.Count < total);
    }
}
