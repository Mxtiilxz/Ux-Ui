// ============================================================
//  Kairos.Infrastructure / Data / ApplicationDbContext.cs
// ============================================================

using Kairos.Domain.Entities;
using Kairos.Application.Common.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace Kairos.Infrastructure.Data;

public class ApplicationDbContext : DbContext, IApplicationDbContext
{
    public ApplicationDbContext(DbContextOptions<ApplicationDbContext> options)
        : base(options) { }

    // ── DbSets (una propiedad por tabla) ─────────────────────
    public DbSet<User>           Users           { get; set; }
    public DbSet<Post>           Posts           { get; set; }
    public DbSet<Comment>        Comments        { get; set; }
    public DbSet<Like>           Likes           { get; set; }
    public DbSet<Follow>         Follows         { get; set; }
    public DbSet<JobPosting>     JobPostings     { get; set; }
    public DbSet<JobApplication> JobApplications { get; set; }
    public DbSet<UserActivity>   UserActivities  { get; set; }
    public DbSet<Message>        Messages        { get; set; }
    public DbSet<Skill>          Skills          { get; set; }
    public DbSet<UserSkill>      UserSkills      { get; set; }

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        // ════════════════════════════════════════════════════
        //  USER
        // ════════════════════════════════════════════════════
        modelBuilder.Entity<User>(e =>
        {
            e.ToTable("users");

            e.HasKey(u => u.Id);

            // Username y Email únicos — el sistema no admite duplicados
            e.HasIndex(u => u.Username).IsUnique();
            e.HasIndex(u => u.Email).IsUnique();

            e.Property(u => u.Username).HasMaxLength(50).IsRequired();
            e.Property(u => u.Email).HasMaxLength(255).IsRequired();
            e.Property(u => u.PasswordHash).HasMaxLength(255).IsRequired();
            e.Property(u => u.FullName).HasMaxLength(120).IsRequired();
            e.Property(u => u.Bio).HasMaxLength(500);
            e.Property(u => u.ProfilePictureUrl).HasMaxLength(500);
            e.Property(u => u.Institution).HasMaxLength(200);
            e.Property(u => u.Role).HasMaxLength(20);
            e.Property(u => u.Status).HasMaxLength(20).HasDefaultValue("approved").IsRequired();
            e.Property(u => u.QuickMatchVisible).HasDefaultValue(false).IsRequired();
            e.Property(u => u.QuickMatchMessageTemplate).HasMaxLength(1000);
        });

        // ════════════════════════════════════════════════════
        //  FOLLOW  (many-to-many self-referencing)
        //  Clave compuesta (FollowerId, FollowedId)
        // ════════════════════════════════════════════════════
        modelBuilder.Entity<Follow>(e =>
        {
            e.ToTable("follows");

            // La clave compuesta garantiza que no puedas seguir a alguien dos veces
            e.HasKey(f => new { f.FollowerId, f.FollowedId });

            e.HasOne(f => f.Follower)
             .WithMany(u => u.Following)
             .HasForeignKey(f => f.FollowerId)
             .OnDelete(DeleteBehavior.Cascade);

            e.HasOne(f => f.Followed)
             .WithMany(u => u.Followers)
             .HasForeignKey(f => f.FollowedId)
             .OnDelete(DeleteBehavior.Cascade);

            // Índice para buscar "todos los que sigue este usuario" rápido
            e.HasIndex(f => f.FollowedId);
        });

        // ════════════════════════════════════════════════════
        //  POST
        // ════════════════════════════════════════════════════
        modelBuilder.Entity<Post>(e =>
        {
            e.ToTable("posts");

            e.HasKey(p => p.Id);

            e.Property(p => p.Content).HasMaxLength(2000).IsRequired();
            e.Property(p => p.ImageUrl).HasMaxLength(500);
            e.Property(p => p.EventDate).HasMaxLength(50);

            // Convertir el enum PostType a string en la BD (más legible que un número)
            e.Property(p => p.Type).HasConversion<string>();

            e.HasOne(p => p.Author)
             .WithMany(u => u.Posts)
             .HasForeignKey(p => p.AuthorId)
             .OnDelete(DeleteBehavior.Cascade);

            // Índice para el feed: traer posts ordenados por fecha, del más reciente al más viejo
            e.HasIndex(p => new { p.AuthorId, p.CreatedAt });
        });

        // ════════════════════════════════════════════════════
        //  COMMENT
        // ════════════════════════════════════════════════════
        modelBuilder.Entity<Comment>(e =>
        {
            e.ToTable("comments");

            e.HasKey(c => c.Id);
            e.Property(c => c.Content).HasMaxLength(1000).IsRequired();

            e.HasOne(c => c.Post)
             .WithMany(p => p.Comments)
             .HasForeignKey(c => c.PostId)
             .OnDelete(DeleteBehavior.Cascade);

            e.HasOne(c => c.Author)
             .WithMany(u => u.Comments)
             .HasForeignKey(c => c.AuthorId)
             .OnDelete(DeleteBehavior.Restrict); // No borrar comentarios si borramos el usuario

            // Índice para cargar todos los comentarios de un post rápido
            e.HasIndex(c => c.PostId);
        });

        // ════════════════════════════════════════════════════
        //  LIKE  (clave compuesta UserId + PostId)
        // ════════════════════════════════════════════════════
        modelBuilder.Entity<Like>(e =>
        {
            e.ToTable("likes");

            // Un usuario solo puede dar like una vez al mismo post — la BD lo garantiza
            e.HasKey(l => new { l.UserId, l.PostId });

            e.HasOne(l => l.User)
             .WithMany(u => u.Likes)
             .HasForeignKey(l => l.UserId)
             .OnDelete(DeleteBehavior.Cascade);

            e.HasOne(l => l.Post)
             .WithMany(p => p.Likes)
             .HasForeignKey(l => l.PostId)
             .OnDelete(DeleteBehavior.Cascade);

            e.HasIndex(l => l.PostId);
        });

        // ════════════════════════════════════════════════════
        //  JOB POSTING
        // ════════════════════════════════════════════════════
        modelBuilder.Entity<JobPosting>(e =>
        {
            e.ToTable("job_postings");

            e.HasKey(j => j.Id);
            e.Property(j => j.Title).HasMaxLength(200).IsRequired();
            e.Property(j => j.Description).HasMaxLength(3000).IsRequired();
            e.Property(j => j.Location).HasMaxLength(200);
            e.Property(j => j.ImageUrl).HasMaxLength(500);
            e.Property(j => j.Status).HasConversion<string>();

            e.HasOne(j => j.Company)
             .WithMany(u => u.JobPostings)
             .HasForeignKey(j => j.CompanyId)
             .OnDelete(DeleteBehavior.Cascade);

            // Índice para listar ofertas abiertas ordenadas por fecha
            e.HasIndex(j => new { j.Status, j.CreatedAt });
        });

        // ════════════════════════════════════════════════════
        //  JOB APPLICATION
        // ════════════════════════════════════════════════════
        modelBuilder.Entity<JobApplication>(e =>
        {
            e.ToTable("job_applications");

            e.HasKey(a => a.Id);
            e.Property(a => a.Status).HasConversion<string>();
            e.Property(a => a.CvUrl).HasMaxLength(500);

            e.HasOne(a => a.Job)
             .WithMany(j => j.Applications)
             .HasForeignKey(a => a.JobId)
             .OnDelete(DeleteBehavior.Cascade);

            e.HasOne(a => a.Applicant)
             .WithMany(u => u.Applications)
             .HasForeignKey(a => a.ApplicantId)
             .OnDelete(DeleteBehavior.Restrict);

            // Índice para que una empresa vea sus postulantes rápido
            e.HasIndex(a => new { a.JobId, a.Status });
            // Índice para que un estudiante vea sus postulaciones
            e.HasIndex(a => a.ApplicantId);
        });

        // ════════════════════════════════════════════════════
        //  USER ACTIVITY
        // ════════════════════════════════════════════════════
        modelBuilder.Entity<UserActivity>(e =>
        {
            e.ToTable("user_activities");

            e.HasKey(a => a.Id);
            e.Property(a => a.Description).HasMaxLength(500).IsRequired();
            e.Property(a => a.ActivityType).HasConversion<string>();

            e.HasOne(a => a.User)
             .WithMany(u => u.Activities)
             .HasForeignKey(a => a.UserId)
             .OnDelete(DeleteBehavior.Cascade);

            // Índice para el generador de CV — trae todas las actividades de un usuario
            e.HasIndex(a => new { a.UserId, a.CreatedAt });
        });

        // ════════════════════════════════════════════════════
        //  MESSAGE  (direct messages between users)
        // ════════════════════════════════════════════════════
        modelBuilder.Entity<Message>(e =>
        {
            e.ToTable("messages");

            e.HasKey(m => m.Id);
            e.Property(m => m.Content).HasMaxLength(2000).IsRequired();

            e.HasOne(m => m.Sender)
             .WithMany()
             .HasForeignKey(m => m.SenderId)
             .OnDelete(DeleteBehavior.Cascade);

            e.HasOne(m => m.Receiver)
             .WithMany()
             .HasForeignKey(m => m.ReceiverId)
             .OnDelete(DeleteBehavior.Restrict);

            // Índice para cargar la conversación entre dos usuarios
            e.HasIndex(m => new { m.SenderId, m.ReceiverId, m.CreatedAt });
        });

        // ════════════════════════════════════════════════════
        //  SKILL  (catálogo curado de competencias — Quick Match)
        // ════════════════════════════════════════════════════
        modelBuilder.Entity<Skill>(e =>
        {
            e.ToTable("skills");

            e.HasKey(s => s.Id);
            e.Property(s => s.Name).HasMaxLength(100).IsRequired();
            e.Property(s => s.Category).HasConversion<string>();

            // No se puede duplicar el mismo nombre de competencia en el catálogo
            e.HasIndex(s => s.Name).IsUnique();
        });

        // ════════════════════════════════════════════════════
        //  USER SKILL  (clave compuesta UserId + SkillId)
        // ════════════════════════════════════════════════════
        modelBuilder.Entity<UserSkill>(e =>
        {
            e.ToTable("user_skills");

            // Un estudiante no puede agregar la misma competencia dos veces
            e.HasKey(us => new { us.UserId, us.SkillId });

            e.HasOne(us => us.User)
             .WithMany(u => u.Skills)
             .HasForeignKey(us => us.UserId)
             .OnDelete(DeleteBehavior.Cascade);

            e.HasOne(us => us.Skill)
             .WithMany(s => s.UserSkills)
             .HasForeignKey(us => us.SkillId)
             .OnDelete(DeleteBehavior.Cascade);

            // Índice para la búsqueda de Quick Match: "qué usuarios tienen la competencia X"
            e.HasIndex(us => us.SkillId);
        });
    }
}
