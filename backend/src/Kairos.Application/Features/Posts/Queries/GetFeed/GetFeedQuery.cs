using MediatR;

namespace Kairos.Application.Features.Posts.Queries.GetFeed;

/// <summary>
/// Feed del usuario. Necesita saber quién mira, no solo la página: cada autor
/// decide si sus publicaciones son públicas o solo para sus contactos.
/// </summary>
public record GetFeedQuery(int ViewerId, int Page = 1, int PageSize = 20) : IRequest<GetFeedResult>;

public record PostDto(
    int      Id,
    int      AuthorId,
    string   AuthorName,
    string   AuthorRole,
    string?  AuthorProfilePictureUrl,
    string   Content,
    string   PostType,    // "General" | "Event" | "Job"
    string?  ImageUrl,
    string?  ImageAltText,
    string?  EventDate,
    int      LikesCount,
    int      CommentsCount,
    DateTime CreatedAt);

public record GetFeedResult(
    IReadOnlyList<PostDto> Items,
    int  TotalCount,
    bool HasNextPage);
