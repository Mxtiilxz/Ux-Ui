// ── JobPosting ───────────────────────────────────────────────
// Oferta laboral creada por una empresa.
namespace Kairos.Domain.Entities;
public enum JobStatus      { Open, Closed, Draft }

public class JobPosting
{
    public int       Id          { get; set; }
    public string    Title       { get; set; } = string.Empty;
    public string    Description { get; set; } = string.Empty;
    public string?   Location    { get; set; }
    public string?   ImageUrl    { get; set; }
    public JobStatus Status      { get; set; } = JobStatus.Open;
    public DateTime  CreatedAt   { get; set; } = DateTime.UtcNow;
    public DateTime? ExpiresAt   { get; set; }

    public int  CompanyId { get; set; }  // FK al User empresa
    public User Company   { get; set; } = null!;

    public ICollection<JobApplication> Applications { get; set; } = [];

    /// <summary>Competencias que la oferta solicita, del catálogo de Quick Match.</summary>
    public ICollection<JobPostingSkill> Skills { get; set; } = [];
}