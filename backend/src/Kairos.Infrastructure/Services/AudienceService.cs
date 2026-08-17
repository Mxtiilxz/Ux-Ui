using Kairos.Application.Common.Interfaces;
using Kairos.Domain.Entities;
using Kairos.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;

namespace Kairos.Infrastructure.Services;

public class AudienceService(ApplicationDbContext db) : IAudienceService
{
    public async Task<bool> CanSendMessageAsync(
        int senderId,
        int receiverId,
        CancellationToken cancellationToken = default)
    {
        if (senderId == receiverId) return true;

        var receiver = await db.Users
            .Where(u => u.Id == receiverId)
            .Select(u => new { u.MessagePrivacy, u.QuickMatchVisible })
            .FirstOrDefaultAsync(cancellationToken);

        if (receiver is null) return false;
        if (receiver.MessagePrivacy == PrivacyAudience.Everyone) return true;

        var sender = await db.Users
            .Where(u => u.Id == senderId)
            .Select(u => u.Role)
            .FirstOrDefaultAsync(cancellationToken);

        // El personal del liceo siempre puede escribir: es quien resuelve
        // problemas, y dejarlo fuera convertiría la privacidad en un obstáculo
        // para pedir ayuda.
        if (sender == "staff") return true;

        if (receiver.MessagePrivacy == PrivacyAudience.Staff) return false;

        // Un alumno que se hizo visible en Quick Match ya aceptó que las
        // empresas lo contacten; sería contradictorio ofrecerse ahí y bloquear
        // el mensaje que sigue.
        if (sender == "company" && receiver.QuickMatchVisible) return true;

        return await AreConnectedAsync(senderId, receiverId, cancellationToken);
    }

    public async Task<IReadOnlySet<int>> VisibleAuthorsAsync(
        int viewerId,
        CancellationToken cancellationToken = default)
    {
        // Autores abiertos a todo el mundo, más los contactos del lector, más él
        // mismo: nadie deja de ver sus propias publicaciones por restringirlas.
        var open = await db.Users
            .Where(u => u.PostVisibility == PrivacyAudience.Everyone)
            .Select(u => u.Id)
            .ToListAsync(cancellationToken);

        var connections = await ConnectionIdsAsync(viewerId, cancellationToken);

        var visible = open.ToHashSet();
        visible.UnionWith(connections);
        visible.Add(viewerId);
        return visible;
    }

    private async Task<bool> AreConnectedAsync(int a, int b, CancellationToken cancellationToken) =>
        await db.Follows.AnyAsync(
            f => f.Status == ConnectionStatus.Accepted &&
                 ((f.FollowerId == a && f.FollowedId == b) ||
                  (f.FollowerId == b && f.FollowedId == a)),
            cancellationToken);

    private async Task<List<int>> ConnectionIdsAsync(int userId, CancellationToken cancellationToken) =>
        await db.Follows
            .Where(f => f.Status == ConnectionStatus.Accepted &&
                        (f.FollowerId == userId || f.FollowedId == userId))
            .Select(f => f.FollowerId == userId ? f.FollowedId : f.FollowerId)
            .ToListAsync(cancellationToken);
}
