namespace Kairos.Application.Common.Interfaces;

/// <summary>
/// Resuelve las preferencias de privacidad: quién puede escribirle a quién y
/// quién ve las publicaciones de quién.
///
/// Vive en un solo lugar porque la misma regla se aplica desde varios puntos —
/// el envío de mensajes, el feed, el contacto de Quick Match — y tenerla
/// repetida garantizaba que alguna copia se quedara atrás.
/// </summary>
public interface IAudienceService
{
    /// <summary>¿Puede <paramref name="senderId"/> escribirle a <paramref name="receiverId"/>?</summary>
    Task<bool> CanSendMessageAsync(int senderId, int receiverId, CancellationToken cancellationToken = default);

    /// <summary>Ids de los usuarios cuyas publicaciones puede ver <paramref name="viewerId"/>.</summary>
    Task<IReadOnlySet<int>> VisibleAuthorsAsync(int viewerId, CancellationToken cancellationToken = default);
}
