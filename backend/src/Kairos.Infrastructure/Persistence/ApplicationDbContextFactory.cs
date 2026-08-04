// ============================================================
//  Kairos.Infrastructure / Persistence / ApplicationDbContextFactory.cs
//  Solo lo usa dotnet ef en tiempo de diseño (migraciones).
//  No afecta el comportamiento en producción.
// ============================================================

using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Design;

namespace Kairos.Infrastructure.Data;

public class ApplicationDbContextFactory : IDesignTimeDbContextFactory<ApplicationDbContext>
{
    public ApplicationDbContext CreateDbContext(string[] args)
    {
        var optionsBuilder = new DbContextOptionsBuilder<ApplicationDbContext>();

        // Esta cadena solo se usa para generar migraciones; no necesita apuntar a una
        // base de datos que exista realmente. Cuando la app corre de verdad usa la de
        // configuración (ConnectionStrings__DefaultConnection).
        //
        // Para ejecutar `dotnet ef database update` contra una base concreta —por
        // ejemplo la de Supabase— exportar KAIROS_DESIGN_TIME_CONNECTION.
        var connectionString =
            Environment.GetEnvironmentVariable("KAIROS_DESIGN_TIME_CONNECTION")
            ?? "Host=localhost;Port=5432;Database=kairos;Username=postgres;Password=postgres";

        optionsBuilder.UseNpgsql(connectionString);

        return new ApplicationDbContext(optionsBuilder.Options);
    }
}
