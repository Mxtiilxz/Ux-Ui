using System.Net.Http.Headers;
using Kairos.Application.Common.Interfaces;
using Microsoft.Extensions.Options;

namespace Kairos.Infrastructure.Services;

public class SupabaseStorageOptions
{
    public const string Section = "Supabase";

    /// <summary>URL del proyecto, por ejemplo https://abcdefgh.supabase.co</summary>
    public string Url { get; set; } = string.Empty;

    /// <summary>
    /// Clave <c>service_role</c>. Salta las políticas de Row Level Security, así que
    /// vive solo en el servidor y nunca debe llegar al cliente Flutter.
    /// </summary>
    public string ServiceKey { get; set; } = string.Empty;

    /// <summary>Nombre del bucket. Debe estar marcado como público para que las imágenes se puedan mostrar.</summary>
    public string Bucket { get; set; } = "kairos-media";
}

/// <summary>
/// Almacenamiento sobre la API REST de Supabase Storage.
///
/// Sube con <c>POST /storage/v1/object/{bucket}/{ruta}</c> autenticando con la clave
/// <c>service_role</c>, y devuelve la URL pública del bucket. Requiere que el bucket
/// sea público; con uno privado habría que firmar URLs temporales en cada lectura,
/// lo que obligaría a cambiar <see cref="IStorageService"/>.
/// </summary>
public class SupabaseStorageService(
    IOptions<SupabaseStorageOptions> options,
    IHttpClientFactory httpClientFactory) : IStorageService
{
    private readonly SupabaseStorageOptions _opts = options.Value;

    public async Task<string> UploadAsync(
        Stream fileStream,
        string fileName,
        string contentType,
        CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(_opts.Url) || string.IsNullOrWhiteSpace(_opts.ServiceKey))
            throw new InvalidOperationException(
                "Supabase Storage no está configurado. Definir Supabase__Url y Supabase__ServiceKey.");

        var client = httpClientFactory.CreateClient();
        client.Timeout = TimeSpan.FromSeconds(30);

        var endpoint = $"{_opts.Url.TrimEnd('/')}/storage/v1/object/{_opts.Bucket}/{Uri.EscapeDataString(fileName)}";

        using var content = new StreamContent(fileStream);
        content.Headers.ContentType = new MediaTypeHeaderValue(contentType);

        using var request = new HttpRequestMessage(HttpMethod.Post, endpoint) { Content = content };
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", _opts.ServiceKey);
        // Sin esto, subir dos veces el mismo nombre devuelve 409 en vez de sobrescribir.
        request.Headers.Add("x-upsert", "true");

        using var response = await client.SendAsync(request, cancellationToken);

        if (!response.IsSuccessStatusCode)
        {
            var body = await response.Content.ReadAsStringAsync(cancellationToken);
            throw new InvalidOperationException(
                $"Supabase Storage devolvió {(int)response.StatusCode}: {body}");
        }

        return GetCdnUrl(fileName);
    }

    public string GetCdnUrl(string blobName) =>
        $"{_opts.Url.TrimEnd('/')}/storage/v1/object/public/{_opts.Bucket}/{Uri.EscapeDataString(blobName)}";
}
