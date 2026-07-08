using Kairos.Application.Common.Exceptions;
using Kairos.Application.Common.Interfaces;
using Kairos.Domain.Entities;
using MediatR;

namespace Kairos.Application.Features.Posts.Commands.CreatePost;

public class CreatePostCommandHandler(IApplicationDbContext db)
    : IRequestHandler<CreatePostCommand, int>
{
    public async Task<int> Handle(CreatePostCommand request, CancellationToken cancellationToken)
    {
        // ── Parse post type ────────────────────────────────────────────────────
        var postType = Enum.TryParse<PostType>(request.PostType, ignoreCase: true, out var parsed)
            ? parsed
            : PostType.General;

        // ── Role-based authorization ───────────────────────────────────────────
        // Event posts: only company or staff
        if (postType == PostType.Event &&
            request.AuthorRole != "company" &&
            request.AuthorRole != "staff")
        {
            throw new ForbiddenException(
                "Solo organizaciones y docentes (company / staff) pueden publicar eventos.");
        }

        // Job posts: only company
        // Note: not currently exposed from the frontend — job offers are created
        // via the separate JobPosting system (JobsController, /api/jobs) instead.
        if (postType == PostType.Job && request.AuthorRole != "company")
        {
            throw new ForbiddenException(
                "Solo organizaciones (company) pueden publicar ofertas de trabajo.");
        }

        // ── Persist post ───────────────────────────────────────────────────────
        var post = new Post
        {
            AuthorId  = request.AuthorId,
            Content   = request.Content,
            Type      = postType,
            ImageUrl  = request.ImageUrl,
            EventDate = request.EventDate,
        };

        db.Posts.Add(post);

        db.UserActivities.Add(new UserActivity
        {
            UserId       = request.AuthorId,
            ActivityType = ActivityType.PostCreated,
            Description  = $"Publicó ({postType}): \"{request.Content[..Math.Min(60, request.Content.Length)]}...\""
        });

        await db.SaveChangesAsync(cancellationToken);
        return post.Id;
    }
}
