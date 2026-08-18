using Kairos.Application.Features.Network.Queries.GetNetworkSuggestions;
using Kairos.Application.Features.Stats.Queries.GetCommunityStats;
using Kairos.Domain.Entities;
using Kairos.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;

namespace Kairos.Application.Tests;

/// <summary>
/// Comprueba que las consultas que alimentan el feed y la pestaña Red se pueden
/// traducir a SQL de PostgreSQL.
///
/// Existen porque dos de ellas no se podían, y el fallo no aparecía en ninguna
/// comprobación: <c>dotnet build</c> las compila sin quejarse, y EF Core solo
/// descubre que no sabe traducir una expresión al construir la consulta, ya en
/// tiempo de ejecución. El resultado fue una API que respondía 409 en
/// producción mientras todo lo demás decía estar bien.
///
/// No hace falta una base de datos: la traducción ocurre al compilar la
/// consulta, así que <c>ToQueryString()</c> lanza exactamente la misma
/// excepción que lanzaría el servidor, sin conectarse a ningún sitio.
/// </summary>
public class LinqTranslationTests
{
    private static ApplicationDbContext CreateContext()
    {
        // Cadena sintáctica: nunca se abre una conexión.
        var options = new DbContextOptionsBuilder<ApplicationDbContext>()
            .UseNpgsql("Host=localhost;Database=kairos;Username=postgres;Password=postgres")
            .Options;

        return new ApplicationDbContext(options);
    }

    [Fact]
    public void Las_competencias_mas_registradas_se_traducen()
    {
        using var db = CreateContext();
        const int limite = 6;

        var consulta = db.Skills
            .Where(s => s.UserSkills.Any())
            .OrderByDescending(s => s.UserSkills.Count)
            .ThenBy(s => s.Name)
            .Take(limite)
            .Select(s => new SkillSupply(s.Id, s.Name, s.UserSkills.Count));

        // Si no fuese traducible, esto lanzaría InvalidOperationException.
        Assert.Contains("SELECT", consulta.ToQueryString());
    }

    [Fact]
    public void Las_competencias_mas_solicitadas_se_traducen()
    {
        using var db = CreateContext();
        const int limite = 6;

        var consulta = db.Skills
            .Where(s => s.JobPostings.Any(js => js.JobPosting.Status == JobStatus.Open))
            .OrderByDescending(s =>
                s.JobPostings.Count(js => js.JobPosting.Status == JobStatus.Open))
            .ThenBy(s => s.Name)
            .Take(limite)
            .Select(s => new SkillDemand(
                s.Id,
                s.Name,
                s.JobPostings.Count(js => js.JobPosting.Status == JobStatus.Open)));

        Assert.Contains("SELECT", consulta.ToQueryString());
    }

    [Fact]
    public void Los_contactos_conectados_se_traducen()
    {
        using var db = CreateContext();
        const int yo = 1;

        // Paso 1: los identificadores del otro extremo de cada conexión.
        var idsConsulta = db.Follows
            .Where(f => f.Status == ConnectionStatus.Accepted &&
                        (f.FollowerId == yo || f.FollowedId == yo))
            .Select(f => f.FollowerId == yo ? f.FollowedId : f.FollowerId);

        Assert.Contains("SELECT", idsConsulta.ToQueryString());

        // Paso 2: los datos de esas personas.
        var ids = new List<int> { 2, 3 };
        var contactosConsulta = db.Users
            .Where(u => ids.Contains(u.Id))
            .OrderBy(u => u.FullName)
            .Select(u => new UserSuggestionDto(
                u.Id,
                u.FullName,
                u.Institution,
                u.ProfilePictureUrl,
                null,
                u.Bio,
                u.Role,
                db.Follows.Count(c => c.Status == ConnectionStatus.Accepted &&
                                      (c.FollowerId == u.Id || c.FollowedId == u.Id)),
                "connected"));

        Assert.Contains("SELECT", contactosConsulta.ToQueryString());
    }

    // ── Los dos casos que sí rompieron producción ────────────────────────────
    //
    // Ambos endpoints fallaban por lo mismo: operar sobre un registro posicional
    // que ya había sido proyectado. Una vez hecho el `Select`, EF Core no puede
    // relacionar `s.StudentCount` o `u.FullName` con ninguna columna, y en vez
    // de resolverlo en memoria se niega a traducir la consulta entera.
    //
    // (Un condicional entre dos navegaciones —`f.X == yo ? f.Followed :
    // f.Follower`— sí se traduce; se comprobó y no era la causa.)

    [Fact]
    public void Filtrar_despues_de_proyectar_a_un_registro_no_se_traduce()
    {
        using var db = CreateContext();

        // Tal como estaba en GetCommunityStatsQueryHandler.
        var consulta = db.Skills
            .Select(s => new SkillSupply(s.Id, s.Name, s.UserSkills.Count))
            .Where(s => s.StudentCount > 0)
            .OrderByDescending(s => s.StudentCount);

        Assert.Throws<InvalidOperationException>(() => consulta.ToQueryString());
    }

    [Fact]
    public void Ordenar_despues_de_proyectar_a_un_registro_no_se_traduce()
    {
        using var db = CreateContext();
        const int yo = 1;

        // Tal como estaba en GetConnectionsQueryHandler: el `OrderBy` iba
        // después del `Select`, sobre el campo del DTO y no sobre la entidad.
        var consulta = db.Follows
            .Where(f => f.Status == ConnectionStatus.Accepted &&
                        (f.FollowerId == yo || f.FollowedId == yo))
            .Select(f => f.FollowerId == yo ? f.Followed : f.Follower)
            .Select(u => new UserSuggestionDto(
                u.Id,
                u.FullName,
                u.Institution,
                u.ProfilePictureUrl,
                null,
                u.Bio,
                u.Role,
                db.Follows.Count(c => c.Status == ConnectionStatus.Accepted &&
                                      (c.FollowerId == u.Id || c.FollowedId == u.Id)),
                "connected"))
            .OrderBy(u => u.FullName);

        Assert.Throws<InvalidOperationException>(() => consulta.ToQueryString());
    }
}
