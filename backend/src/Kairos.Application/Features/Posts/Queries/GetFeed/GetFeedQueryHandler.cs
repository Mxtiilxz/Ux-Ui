using Kairos.Application.Common.Interfaces;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace Kairos.Application.Features.Posts.Queries.GetFeed;

public class GetFeedQueryHandler(IApplicationDbContext db)
    : IRequestHandler<GetFeedQuery, GetFeedResult>
{
    public async Task<GetFeedResult> Handle(GetFeedQuery request, CancellationToken cancellationToken)
    {
        if (request.Page < 1)
            throw new ArgumentException("El número de página debe ser mayor a 0.");

        var skip  = (request.Page - 1) * request.PageSize;
        var total = await db.Posts.CountAsync(cancellationToken);

        var posts = await db.Posts
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
