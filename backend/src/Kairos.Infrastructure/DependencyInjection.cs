// ============================================================
//  Kairos.Infrastructure / DependencyInjection.cs
//  Llamar el metodo "builder.Services.AddInfrastructure(builder.Configuration)" desde Program.cs
// ============================================================

using Kairos.Application.Common.Interfaces;
using Kairos.Infrastructure.Data;
using Kairos.Infrastructure.Services;
using Microsoft.AspNetCore.Hosting;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;

namespace Kairos.Infrastructure;

public static class DependencyInjection
{
    public static IServiceCollection AddInfrastructure(
        this IServiceCollection services,
        IConfiguration configuration,
        IWebHostEnvironment env)
    {
        var connectionString = configuration.GetConnectionString("DefaultConnection")
            ?? throw new InvalidOperationException(
                "No se encontró 'DefaultConnection'. En producción se define con la variable " +
                "de entorno ConnectionStrings__DefaultConnection.");

        services.AddDbContext<ApplicationDbContext>(options =>
            options.UseNpgsql(
                connectionString,
                npgsqlOptions =>
                {
                    // Reintentar hasta 3 veces si la BD no está disponible al arrancar.
                    // Supabase pausa los proyectos gratuitos tras 7 días sin actividad y
                    // tarda unos segundos en despertar, así que el reintento importa.
                    npgsqlOptions.EnableRetryOnFailure(
                        maxRetryCount: 3,
                        maxRetryDelay: TimeSpan.FromSeconds(5),
                        errorCodesToAdd: null);
                }
            )
        );

        // Registrar la interfaz → implementación concreta
        // Cuando algo pide IApplicationDbContext, DI entrega ApplicationDbContext
        services.AddScoped<IApplicationDbContext>(
            provider => provider.GetRequiredService<ApplicationDbContext>());

        // JWT
        services.Configure<JwtOptions>(configuration.GetSection(JwtOptions.Section));
        services.AddScoped<IJwtService, JwtService>();
        services.AddScoped<IAudienceService, AudienceService>();

        // Storage: filesystem local en desarrollo, Supabase Storage en producción.
        // En Development no hace falta configurar nada de Supabase.
        services.Configure<SupabaseStorageOptions>(configuration.GetSection(SupabaseStorageOptions.Section));
        services.AddHttpClient();

        if (env.IsDevelopment())
            services.AddScoped<IStorageService, LocalStorageService>();
        else
            services.AddScoped<IStorageService, SupabaseStorageService>();

        // PDF generation
        services.AddScoped<ICurriculumGenerator, CurriculumGenerator>();
        services.AddScoped<IReportGeneratorService, ReportGeneratorService>();

        return services;
    }
}
