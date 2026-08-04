using System.Net;
using System.Security.Claims;
using System.Text;
using System.Threading.RateLimiting;
using FluentValidation;
using Kairos.API.Hubs;
using Kairos.API.Middleware;
using Kairos.API.RateLimit;
using Kairos.Application.Common.Behaviors;
using Kairos.Application.Features.Auth.Commands.Login;
using Kairos.Infrastructure;
using Kairos.Infrastructure.Data;
using Kairos.Infrastructure.Persistence;
using MediatR;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using Microsoft.OpenApi.Models;

var builder = WebApplication.CreateBuilder(args);

// ── Infrastructure (PostgreSQL, Storage, JWT, PDF) ────────────────────────────
builder.Services.AddInfrastructure(builder.Configuration, builder.Environment);

// ── Application (MediatR + FluentValidation) ──────────────────────────────────
builder.Services.AddMediatR(cfg =>
{
    cfg.RegisterServicesFromAssemblyContaining<LoginCommand>();
    cfg.AddOpenBehavior(typeof(ValidationBehavior<,>));
});

builder.Services.AddValidatorsFromAssemblyContaining<LoginCommand>();

// ── Authentication (JWT Bearer) ───────────────────────────────────────────────
// appsettings.json ya no trae la clave: en producción llega por la variable de
// entorno Jwt__SecretKey y en desarrollo desde appsettings.Development.json.
// Se comprueba que no venga vacía, no solo que no sea null, porque una cadena
// vacía firmaría tokens con una clave trivial en vez de fallar al arrancar.
var jwtKey = builder.Configuration["Jwt:SecretKey"];
if (string.IsNullOrWhiteSpace(jwtKey))
    throw new InvalidOperationException(
        "Falta la clave JWT. Definir la variable de entorno Jwt__SecretKey " +
        "(mínimo 32 caracteres).");

builder.Services
    .AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(opts =>
    {
        opts.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer           = true,
            ValidateAudience         = true,
            ValidateLifetime         = true,
            ValidateIssuerSigningKey = true,
            ValidIssuer              = builder.Configuration["Jwt:Issuer"],
            ValidAudience            = builder.Configuration["Jwt:Audience"],
            IssuerSigningKey         = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtKey))
        };

        // Allow JWT via SignalR query string
        opts.Events = new JwtBearerEvents
        {
            OnMessageReceived = ctx =>
            {
                var token = ctx.Request.Query["access_token"];
                if (!string.IsNullOrEmpty(token) &&
                    ctx.Request.Path.StartsWithSegments("/hubs"))
                {
                    ctx.Token = token;
                }
                return Task.CompletedTask;
            }
        };
    });

builder.Services.AddAuthorization();

// ── SignalR ───────────────────────────────────────────────────────────────────
builder.Services.AddSignalR();

// ── Controllers + Swagger ────────────────────────────────────────────────────
builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(c =>
{
    c.SwaggerDoc("v1", new OpenApiInfo { Title = "Kairos API", Version = "v1" });

    c.AddSecurityDefinition("Bearer", new OpenApiSecurityScheme
    {
        Name = "Authorization",
        Type = SecuritySchemeType.Http,
        Scheme = "bearer",
        BearerFormat = "JWT",
        In = ParameterLocation.Header
    });

    c.AddSecurityRequirement(new OpenApiSecurityRequirement
    {
        {
            new OpenApiSecurityScheme
            {
                Reference = new OpenApiReference { Type = ReferenceType.SecurityScheme, Id = "Bearer" }
            },
            []
        }
    });
});

// ── CORS ──────────────────────────────────────────────────────────────────────
builder.Services.AddCors(opts =>
    opts.AddDefaultPolicy(policy =>
        policy.WithOrigins(
                  "https://kairoswebapp.netlify.app",
                  "https://kairoslt.netlify.app",
                  "https://statuesque-llama-6b5882.netlify.app",
                  "http://localhost:3000",
                  "http://localhost:5000",
                  "http://localhost:8080")
              .AllowAnyHeader()
              .AllowAnyMethod()
              .AllowCredentials()));

// ── Rate Limiting ─────────────────────────────────────────────────────────────
builder.Services.AddRateLimiter(options =>
{
    // Login: 5 attempts per 15 minutes, keyed by client IP (localhost is exempt)
    options.AddPolicy("login", context =>
    {
        var ip = context.Connection.RemoteIpAddress;
        if (ip != null && IPAddress.IsLoopback(ip))
            return RateLimitPartition.GetNoLimiter(ip.ToString());

        return RateLimitPartition.GetFixedWindowLimiter(
            partitionKey: ip?.ToString() ?? "unknown",
            factory: _ => new FixedWindowRateLimiterOptions
            {
                PermitLimit = 5,
                Window = TimeSpan.FromMinutes(15),
                QueueLimit = 0
            });
    });

    // CV generation: 5 per 15 min + 20 s minimum gap, keyed by authenticated user ID
    options.AddPolicy<string>("curriculum", context =>
    {
        var userId = context.User.FindFirstValue(ClaimTypes.NameIdentifier) ?? "anon";
        return RateLimitPartition.Get(userId, _ => new CurriculumRateLimiter());
    });

    // Quick Match candidate search: 30 per 5 min, keyed by authenticated user ID
    options.AddPolicy<string>("quickmatch-search", context =>
    {
        var userId = context.User.FindFirstValue(ClaimTypes.NameIdentifier) ?? "anon";
        return RateLimitPartition.GetFixedWindowLimiter(
            partitionKey: userId,
            factory: _ => new FixedWindowRateLimiterOptions
            {
                PermitLimit = 30,
                Window = TimeSpan.FromMinutes(5),
                QueueLimit = 0
            });
    });

    options.RejectionStatusCode = StatusCodes.Status429TooManyRequests;
});

var app = builder.Build();

// ── Auto-apply pending EF Core migrations on startup ─────────────────────────
//
// El esquema completo lo crea la migración inicial de PostgreSQL. La red de
// seguridad `EnsureColumnAsync` que existía aquí era específica de MySQL (usaba
// backticks) y solo hacía falta por la deriva de esquema de la base de Railway;
// sobre una base creada desde cero por las migraciones no tiene sentido.
using (var scope = app.Services.CreateScope())
{
    var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
    await db.Database.MigrateAsync();
}

// ── Seed de datos ─────────────────────────────────────────────────────────────
// En desarrollo se cargan usuarios de prueba completos. En producción solo se
// crea el primer usuario staff, y únicamente si se entregan sus credenciales por
// variables de entorno: sin al menos un staff nadie puede aprobar los registros,
// que nacen en estado "pending".
if (app.Environment.IsDevelopment())
    await DevDataSeeder.SeedAsync(app.Services);
else
    await ProductionSeeder.SeedAsync(app.Services, app.Configuration);

// ── Middleware pipeline ────────────────────────────────────────────────────────
app.UseCors();
app.UseStaticFiles(); // serves wwwroot/uploads/* in dev

if (!app.Environment.IsDevelopment())
    app.UseHttpsRedirection();

app.UseMiddleware<ExceptionHandlingMiddleware>();

if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseAuthentication();
app.UseRateLimiter();
app.UseAuthorization();

// Health check sin autenticación: los hosts gratuitos lo consultan para decidir
// si el contenedor sigue vivo. No toca la base de datos a propósito, para que un
// problema de BD no provoque un reinicio en bucle.
app.MapGet("/health", () => Results.Ok(new { status = "ok" }))
   .AllowAnonymous()
   .ExcludeFromDescription();

app.MapControllers();
app.MapHub<SocialHub>("/hubs/chat");
app.MapHub<SocialHub>("/hubs/social");

app.Run();
