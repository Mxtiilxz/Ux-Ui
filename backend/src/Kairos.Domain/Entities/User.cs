namespace Kairos.Domain.Entities;
// ── User ─────────────────────────────────────────────────────
// Representa a cualquier persona en la plataforma
// (estudiante, empresa o backoffice del liceo).

public class User
{
    public int    Id                { get; set; }
    public string Username          { get; set; } = string.Empty;
    public string Email             { get; set; } = string.Empty;
    public string PasswordHash      { get; set; } = string.Empty;
    public string FullName          { get; set; } = string.Empty;
    public string? Bio              { get; set; }
    public string? ProfilePictureUrl{ get; set; }
    public string? Institution      { get; set; }  // Liceo o empresa
    public string? Role             { get; set; }  // "student" | "company" | "staff"
    public string  Status           { get; set; } = "approved"; // "pending" | "approved" | "rejected"
    public DateTime CreatedAt       { get; set; } = DateTime.UtcNow;

    // Quick Match: el estudiante debe activar esto explícitamente para
    // aparecer en las búsquedas de competencias de las empresas.
    public bool QuickMatchVisible   { get; set; } = false;

    // Quick Match: plantilla de mensaje que la EMPRESA usa al contactar a un
    // candidato desde la búsqueda. Admite los placeholders {nombre}, {empresa}
    // y {competencias}. Null = se usa el mensaje por defecto del sistema.
    public string? QuickMatchMessageTemplate { get; set; }

    // Navegación (EF Core las usa para construir los JOINs)
    public ICollection<Post>            Posts           { get; set; } = [];
    public ICollection<UserActivity>    Activities      { get; set; } = [];
    public ICollection<Comment>         Comments        { get; set; } = [];
    public ICollection<Like>            Likes           { get; set; } = [];
    public ICollection<JobPosting>      JobPostings     { get; set; } = [];
    public ICollection<JobApplication>  Applications    { get; set; } = [];
    public ICollection<UserSkill>       Skills          { get; set; } = [];

    // Seguidores / seguidos  (self-referencing many-to-many)
    public ICollection<Follow>          Followers       { get; set; } = [];
    public ICollection<Follow>          Following       { get; set; } = [];
}