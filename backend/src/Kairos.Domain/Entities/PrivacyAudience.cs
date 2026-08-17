namespace Kairos.Domain.Entities;

/// <summary>
/// Audiencias posibles de una preferencia de privacidad.
///
/// Se guardan como texto y no como enum numérico para que una consulta directa
/// a la base diga qué significa cada fila sin tener que consultar el código.
/// </summary>
public static class PrivacyAudience
{
    /// <summary>Cualquier usuario de la plataforma.</summary>
    public const string Everyone = "everyone";

    /// <summary>Solo los contactos conectados.</summary>
    public const string Connections = "connections";

    /// <summary>Solo el personal del liceo. Solo aplica a los mensajes.</summary>
    public const string Staff = "staff";

    public static bool IsValidForMessages(string? value) =>
        value is Everyone or Connections or Staff;

    public static bool IsValidForPosts(string? value) =>
        value is Everyone or Connections;
}
