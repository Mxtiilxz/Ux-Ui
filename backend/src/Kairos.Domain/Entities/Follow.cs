// ── Follow ───────────────────────────────────────────────────
// Conexión entre dos usuarios.
//
// Empezó siendo un "seguir" unilateral: quien pulsaba el botón quedaba
// conectado sin que la otra persona interviniera. Ahora es bilateral y la fila
// representa una solicitud: FollowerId la envía, FollowedId la recibe, y la
// conexión solo existe cuando el segundo la acepta.
//
// Se conservan los nombres de las columnas para no romper las filas ya
// creadas; léase FollowerId como "quien solicita" y FollowedId como "quien
// recibe la solicitud".

namespace Kairos.Domain.Entities;

public static class ConnectionStatus
{
    public const string Pending  = "pending";
    public const string Accepted = "accepted";
}

public class Follow
{
    /// <summary>Quien envía la solicitud.</summary>
    public int FollowerId   { get; set; }
    public User Follower    { get; set; } = null!;

    /// <summary>Quien la recibe y decide.</summary>
    public int FollowedId   { get; set; }
    public User Followed    { get; set; } = null!;

    /// <summary>"pending" o "accepted". Una solicitud rechazada se borra.</summary>
    public string Status    { get; set; } = ConnectionStatus.Pending;

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    /// <summary>Momento en que se aceptó. Null mientras está pendiente.</summary>
    public DateTime? RespondedAt { get; set; }
}
