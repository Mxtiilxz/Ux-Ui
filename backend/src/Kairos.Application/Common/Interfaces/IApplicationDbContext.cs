// ============================================================
//  Kairos.Application / Common / Interfaces / IApplicationDbContext.cs
//  Reemplaza el archivo existente.
// ============================================================

using Kairos.Domain.Entities;
using Microsoft.EntityFrameworkCore;

namespace Kairos.Application.Common.Interfaces;

// Esta interfaz es el "contrato" que el resto de la aplicación conoce.
// La capa de Application nunca toca ApplicationDbContext directamente —
// solo usa esta interfaz
public interface IApplicationDbContext
{
    DbSet<User>           Users           { get; }
    DbSet<Post>           Posts           { get; }
    DbSet<Comment>        Comments        { get; }
    DbSet<Like>           Likes           { get; }
    DbSet<Follow>         Follows         { get; }
    DbSet<JobPosting>     JobPostings     { get; }
    DbSet<JobApplication> JobApplications { get; }
    DbSet<UserActivity>   UserActivities  { get; }
    DbSet<Message>        Messages        { get; }
    DbSet<Skill>          Skills          { get; }
    DbSet<UserSkill>      UserSkills      { get; }
    DbSet<JobPostingSkill> JobPostingSkills { get; }

    Task<int> SaveChangesAsync(CancellationToken cancellationToken = default);
}
