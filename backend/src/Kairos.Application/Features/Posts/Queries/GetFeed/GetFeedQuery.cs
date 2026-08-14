using MediatR;

namespace Kairos.Application.Features.Posts.Queries.GetFeed;

public record GetFeedQuery(int Page = 1, int PageSize = 20) : IRequest<GetFeedResult>;

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
