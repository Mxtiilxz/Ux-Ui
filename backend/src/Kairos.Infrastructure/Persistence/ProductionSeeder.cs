using Kairos.Domain.Entities;
using Kairos.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;

namespace Kairos.Infrastructure.Persistence;

/// <summary>
/// Prepara un despliegue nuevo: siembra el catálogo de competencias y crea el
/// primer usuario <c>staff</c>.
///
/// Sin esto la plataforma queda bloqueada: <c>RegisterCommandHandler</c> crea a
/// todos los usuarios en estado <c>pending</c> y solo un <c>staff</c> puede
/// aprobarlos, pero <see cref="DevDataSeeder"/> únicamente corre en desarrollo.
/// El resultado es que nadie puede entrar a una instalación recién desplegada.
///
/// Es idempotente y no hace nada salvo que se entreguen las credenciales por
/// configuración, así que es seguro dejarlo en el arranque de forma permanente.
/// </summary>
public static class ProductionSeeder
{
    public const string EmailKey    = "SEED_STAFF_EMAIL";
    public const string PasswordKey = "SEED_STAFF_PASSWORD";
    public const string NameKey     = "SEED_STAFF_NAME";

    public static async Task SeedAsync(IServiceProvider services, IConfiguration configuration)
    {
        using var scope = services.CreateScope();
        var db     = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
        var logger = scope.ServiceProvider
            .GetRequiredService<ILoggerFactory>()
            .CreateLogger(typeof(ProductionSeeder));

        // El catálogo de competencias no depende de ninguna credencial: sin él,
        // Quick Match no funciona aunque el resto de la plataforma esté sana.
        await SkillCatalog.SeedAsync(db);

        var email    = configuration[EmailKey];
        var password = configuration[PasswordKey];

        if (string.IsNullOrWhiteSpace(email) || string.IsNullOrWhiteSpace(password))
        {
            // Caso normal en cada arranque posterior al primero.
            if (!await db.Users.AnyAsync(u => u.Role == "staff"))
            {
                logger.LogWarning(
                    "No existe ningún usuario staff y no se entregaron {EmailKey} / {PasswordKey}. " +
                    "Los registros quedarán bloqueados en estado 'pending' porque nadie podrá aprobarlos.",
                    EmailKey, PasswordKey);
            }
            return;
        }

        if (await db.Users.AnyAsync(u => u.Email == email))
        {
            logger.LogInformation(
                "El usuario staff {Email} ya existe; no se hace nada. " +
                "Conviene quitar {EmailKey} y {PasswordKey} de las variables de entorno.",
                email, EmailKey, PasswordKey);
            return;
        }

        var username = email.Split('@')[0];

        // Username también es único: si choca, se le agrega un sufijo.
        if (await db.Users.AnyAsync(u => u.Username == username))
            username = $"{username}_{Guid.NewGuid().ToString("N")[..6]}";

        db.Users.Add(new User
        {
            Username     = username,
            Email        = email,
            PasswordHash = BCrypt.Net.BCrypt.HashPassword(password),
            FullName     = configuration[NameKey] ?? "Administración",
            Role         = "staff",
            Status       = "approved",
        });

        await db.SaveChangesAsync();

        logger.LogInformation(
            "Usuario staff inicial creado: {Email}. Ya se pueden quitar {EmailKey} y {PasswordKey} " +
            "de las variables de entorno del host.",
            email, EmailKey, PasswordKey);
    }
}
