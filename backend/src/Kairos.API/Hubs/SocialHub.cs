using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;

namespace Kairos.API.Hubs;

[Authorize]
public class SocialHub : Hub
{
    // ── Direct Messages ────────────────────────────────────────────────────────

    /// <summary>Join a DM room with another user.</summary>
    public async Task JoinConversation(string userId, string otherId)
    {
        await Groups.AddToGroupAsync(Context.ConnectionId, DmGroup(userId, otherId));
    }

    /// <summary>Leave a DM room.</summary>
    public async Task LeaveConversation(string userId, string otherId)
    {
        await Groups.RemoveFromGroupAsync(Context.ConnectionId, DmGroup(userId, otherId));
    }

    /// <summary>
    /// Send a direct message via SignalR. The message is also persisted via the
    /// REST endpoint POST /api/chat/messages/{receiverId}.
    /// This method is for real-time delivery only.
    /// </summary>
    public async Task SendDirectMessage(string senderId, string receiverId, string content)
    {
        var groupName = DmGroup(senderId, receiverId);

        await Clients.Group(groupName).SendAsync("ReceiveMessage", new
        {
            senderId,
            content,
            timestamp = DateTime.UtcNow.ToString("HH:mm"),
        });
    }

    /// <summary>Broadcast typing indicator to the other participant in a DM.</summary>
    public async Task SendTypingDm(string senderId, string receiverId)
    {
        var groupName = DmGroup(senderId, receiverId);
        await Clients.OthersInGroup(groupName).SendAsync("UserTyping", senderId);
    }

    // ── Notifications ──────────────────────────────────────────────────────────

    /// <summary>Push a like notification to the post author.</summary>
    /// <remarks>
    /// El nombre de quien reacciona sale del token, no del cliente: si viniera
    /// como argumento, cualquiera podría notificar en nombre de otra persona.
    /// </remarks>
    public async Task NotifyLike(string targetUserId, int postId)
    {
        await Clients.User(targetUserId).SendAsync("ReceiveLike", new
        {
            postId,
            likedByName = ActorName(),
            timestamp = DateTime.UtcNow,
        });
    }

    /// <summary>Push a follow notification to the followed user.</summary>
    public async Task NotifyFollow(string targetUserId)
    {
        await Clients.User(targetUserId).SendAsync("ReceiveFollow", new
        {
            followerName = ActorName(),
            timestamp = DateTime.UtcNow,
        });
    }

    /// <summary>Nombre visible de quien invoca, tomado del claim del JWT.</summary>
    private string ActorName()
        => Context.User?.FindFirst("fullName")?.Value ?? "Alguien";

    // ── Comment sections ───────────────────────────────────────────────────────

    public async Task JoinPostComments(int postId)
        => await Groups.AddToGroupAsync(Context.ConnectionId, PostGroup(postId));

    public async Task LeavePostComments(int postId)
        => await Groups.RemoveFromGroupAsync(Context.ConnectionId, PostGroup(postId));

    public async Task SendComment(int postId, string content)
    {
        var userId = Context.UserIdentifier ?? "unknown";
        await Clients.Group(PostGroup(postId)).SendAsync("ReceiveComment", new
        {
            postId,
            authorId = userId,
            content,
            timestamp = DateTime.UtcNow,
        });
    }

    public async Task SendTyping(int postId)
    {
        var userId = Context.UserIdentifier ?? "unknown";
        await Clients.OthersInGroup(PostGroup(postId)).SendAsync("UserTyping", new
        {
            postId,
            userId,
            timestamp = DateTime.UtcNow,
        });
    }

    // ── Helpers ────────────────────────────────────────────────────────────────

    /// <summary>
    /// Deterministic group name for a DM between two users.
    /// Always sorts the IDs so both sides get the same group name.
    /// </summary>
    private static string DmGroup(string a, string b)
    {
        var sorted = string.Compare(a, b, StringComparison.Ordinal) < 0
            ? (a, b)
            : (b, a);
        return $"dm-{sorted.Item1}-{sorted.Item2}";
    }

    private static string PostGroup(int postId) => $"post-comments-{postId}";
}
