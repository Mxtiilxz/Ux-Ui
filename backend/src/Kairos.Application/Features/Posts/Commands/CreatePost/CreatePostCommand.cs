using MediatR;

namespace Kairos.Application.Features.Posts.Commands.CreatePost;

public record CreatePostCommand(
    int     AuthorId,
    string  AuthorRole,   // "student" | "company" | "staff" — enforced by handler
    string  Content,
    string  PostType,     // "general" | "event" | "job"
    string? ImageUrl,
    string? ImageAltText,
    string? EventDate) : IRequest<int>;
