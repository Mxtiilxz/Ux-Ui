using Kairos.Application.Common.Interfaces;
using Microsoft.AspNetCore.Hosting;
using Microsoft.Extensions.Configuration;

namespace Kairos.Infrastructure.Services;

/// <summary>
/// Dev-only storage: saves files to wwwroot/uploads and serves them as static files.
/// Avoids needing a Supabase account to develop locally.
/// </summary>
public class LocalStorageService(IWebHostEnvironment env, IConfiguration config) : IStorageService
{
    public async Task<string> UploadAsync(
        Stream fileStream,
        string fileName,
        string contentType,
        CancellationToken cancellationToken = default)
    {
        var uploadsDir = Path.Combine(env.WebRootPath, "uploads");
        Directory.CreateDirectory(uploadsDir);

        var dest = Path.Combine(uploadsDir, fileName);
        await using var fs = File.Create(dest);
        await fileStream.CopyToAsync(fs, cancellationToken);

        var baseUrl = config["Urls"]?.Split(';').First().TrimEnd('/') ?? "http://localhost:5001";
        return $"{baseUrl}/uploads/{fileName}";
    }

    public string GetCdnUrl(string blobName)
    {
        var baseUrl = config["Urls"]?.Split(';').First().TrimEnd('/') ?? "http://localhost:5001";
        return $"{baseUrl}/uploads/{blobName}";
    }
}
