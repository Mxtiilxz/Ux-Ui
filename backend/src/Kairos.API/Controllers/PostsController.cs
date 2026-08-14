using System.Security.Claims;
using Kairos.Application.Features.Posts.Commands.AddComment;
using Kairos.Application.Features.Posts.Commands.CreatePost;
using Kairos.Application.Features.Posts.Commands.DeletePost;
using Kairos.Application.Features.Posts.Commands.LikePost;
using Kairos.Application.Features.Posts.Commands.UpdatePost;
using Kairos.Application.Features.Posts.Queries.GetFeed;
using Kairos.Application.Features.Posts.Queries.GetPostComments;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Kairos.API.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class PostsController(IMediator mediator) : ControllerBase
{
    private int GetUserId() => int.Parse(
        User.FindFirstValue(ClaimTypes.NameIdentifier)
        ?? User.FindFirstValue("sub")
        ?? throw new UnauthorizedAccessException());

    private string GetUserRole() => User.FindFirstValue(ClaimTypes.Role) ?? "student";

    // ── Feed ─────────────────────────────────────────────────────────────────

    [HttpGet("feed")]
    [ProducesResponseType(typeof(GetFeedResult), StatusCodes.Status200OK)]
    public async Task<IActionResult> GetFeed(
        [FromQuery] int page     = 1,
        [FromQuery] int pageSize = 20,
        CancellationToken ct     = default)
    {
        var result = await mediator.Send(new GetFeedQuery(page, pageSize), ct);
        return Ok(result);
    }

    // ── Create post ───────────────────────────────────────────────────────────

    [HttpPost]
    [ProducesResponseType(typeof(int), StatusCodes.Status201Created)]
    public async Task<IActionResult> CreatePost(
        [FromBody] CreatePostRequest request,
        CancellationToken ct)
    {
        var authorId   = GetUserId();
        var authorRole = User.FindFirstValue(ClaimTypes.Role) ?? "student";

        var command = new CreatePostCommand(
            authorId, authorRole, request.Content,
            request.PostType, request.ImageUrl, request.ImageAltText, request.EventDate);

        var postId = await mediator.Send(command, ct);
        return CreatedAtAction(nameof(GetFeed), new { id = postId }, postId);
    }

    // ── Like / Unlike (toggle) ────────────────────────────────────────────────

    // ── Delete post ───────────────────────────────────────────────────────────

    [HttpDelete("{postId:int}")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    public async Task<IActionResult> DeletePost(int postId, CancellationToken ct)
    {
        await mediator.Send(new DeletePostCommand(postId, GetUserId(), GetUserRole()), ct);
        return NoContent();
    }

    // ── Update post ───────────────────────────────────────────────────────────

    [HttpPut("{postId:int}")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    public async Task<IActionResult> UpdatePost(int postId, [FromBody] UpdatePostRequest request, CancellationToken ct)
    {
        await mediator.Send(new UpdatePostCommand(postId, GetUserId(), request.Content), ct);
        return NoContent();
    }

    // ── Like / Unlike (toggle) ────────────────────────────────────────────────

    [HttpPost("{postId:int}/like")]
    [ProducesResponseType(typeof(LikeResult), StatusCodes.Status200OK)]
    public async Task<IActionResult> ToggleLike(int postId, CancellationToken ct)
    {
        var newCount = await mediator.Send(new LikePostCommand(postId, GetUserId()), ct);
        return Ok(new LikeResult(postId, newCount));
    }

    // ── Comments ──────────────────────────────────────────────────────────────

    [HttpGet("{postId:int}/comments")]
    [ProducesResponseType(typeof(IReadOnlyList<CommentDto>), StatusCodes.Status200OK)]
    public async Task<IActionResult> GetComments(
        int postId,
        [FromQuery] int page     = 1,
        [FromQuery] int pageSize = 20,
        CancellationToken ct     = default)
    {
        var result = await mediator.Send(new GetPostCommentsQuery(postId, page, pageSize), ct);
        return Ok(result);
    }

    [HttpPost("{postId:int}/comments")]
    [ProducesResponseType(typeof(CommentDto), StatusCodes.Status201Created)]
    public async Task<IActionResult> AddComment(
        int postId,
        [FromBody] AddCommentRequest request,
        CancellationToken ct)
    {
        var dto = await mediator.Send(new AddCommentCommand(postId, GetUserId(), request.Content), ct);
        return CreatedAtAction(nameof(GetComments), new { postId }, dto);
    }
}

public record CreatePostRequest(
    string  Content,
    string  PostType     = "general",
    string? ImageUrl     = null,
    string? ImageAltText = null,
    string? EventDate    = null);

public record AddCommentRequest(string Content);
public record UpdatePostRequest(string Content);

public record LikeResult(int PostId, int LikesCount);
