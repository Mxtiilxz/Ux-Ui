using System.Net;
using System.Text.Json;
using FluentValidation;
using Kairos.Application.Common.Exceptions;
using Microsoft.EntityFrameworkCore;

namespace Kairos.API.Middleware;

public class ExceptionHandlingMiddleware(RequestDelegate next, ILogger<ExceptionHandlingMiddleware> logger)
{
    public async Task InvokeAsync(HttpContext context)
    {
        try
        {
            await next(context);
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Unhandled exception for {Method} {Path}", context.Request.Method, context.Request.Path);
            await WriteProblemDetailsAsync(context, ex);
        }
    }

    private static Task WriteProblemDetailsAsync(HttpContext context, Exception ex)
    {
        var (statusCode, title) = ex switch
        {
            ValidationException         => (HttpStatusCode.BadRequest,           "Solicitud inválida."),
            AccountNotApprovedException => (HttpStatusCode.Forbidden,             "Cuenta no habilitada."),
            UnauthorizedAccessException => (HttpStatusCode.Unauthorized,          "No autorizado."),
            ForbiddenException          => (HttpStatusCode.Forbidden,             "Acción no permitida."),
            KeyNotFoundException        => (HttpStatusCode.NotFound,              "Recurso no encontrado."),
            InvalidOperationException   => (HttpStatusCode.Conflict,              "Operación inválida."),
            ArgumentException           => (HttpStatusCode.BadRequest,            "Solicitud inválida."),
            DbUpdateException           => (HttpStatusCode.InternalServerError,   "Error al guardar en la base de datos."),
            _                           => (HttpStatusCode.InternalServerError,   "Error interno del servidor.")
        };

        context.Response.ContentType = "application/problem+json";
        context.Response.StatusCode = (int)statusCode;

        var problemDetails = new
        {
            type = $"https://httpstatuses.com/{(int)statusCode}",
            title,
            status = (int)statusCode,
            detail = ex.Message,
            instance = context.Request.Path.Value,
            // Campo legible por el cliente para distinguir "espera aprobación"
            // de "cuenta rechazada" sin tener que interpretar el texto.
            accountStatus = (ex as AccountNotApprovedException)?.AccountStatus,
        };

        return context.Response.WriteAsync(JsonSerializer.Serialize(problemDetails));
    }
}
