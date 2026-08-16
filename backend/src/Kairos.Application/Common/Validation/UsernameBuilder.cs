using System.Globalization;
using System.Text;

namespace Kairos.Application.Common.Validation;

/// <summary>
/// Genera el nombre de usuario a partir del nombre real.
///
/// Antes el nombre de usuario lo elegía quien se registraba, lo que dejaba al
/// liceo sin control sobre cómo aparecen sus alumnos en la plataforma. Ahora se
/// deriva en el servidor: un alumno es su primer nombre y su primer apellido, y
/// una empresa es su razón social.
/// </summary>
public static class UsernameBuilder
{
    /// <summary>Primer nombre + primer apellido, ej. "Ana María Pérez Soto" → "ana.perez".</summary>
    public static string ForPerson(string firstNames, string lastNames)
    {
        var firstName = FirstWord(firstNames);
        var lastName  = FirstWord(lastNames);

        var candidate = string.Join('.', new[] { firstName, lastName }.Where(p => p.Length > 0));
        return candidate.Length > 0 ? candidate : "usuario";
    }

    /// <summary>Razón social completa, ej. "TechSolutions Chile SpA" → "techsolutions-chile-spa".</summary>
    public static string ForCompany(string companyName)
    {
        var slug = string.Join('-', Normalize(companyName)
            .Split(' ', StringSplitOptions.RemoveEmptyEntries));

        return slug.Length > 0 ? Truncate(slug) : "empresa";
    }

    private static string FirstWord(string value)
    {
        var words = Normalize(value).Split(' ', StringSplitOptions.RemoveEmptyEntries);
        return words.Length > 0 ? Truncate(words[0]) : string.Empty;
    }

    /// <summary>
    /// Minúsculas, sin tildes y sin caracteres raros. Las tildes se quitan
    /// descomponiendo el texto y descartando los diacríticos, para que "Muñoz"
    /// y "Munoz" no produzcan dos usuarios distintos.
    /// </summary>
    private static string Normalize(string value)
    {
        var decomposed = value.Trim().ToLowerInvariant().Normalize(NormalizationForm.FormD);
        var builder = new StringBuilder(decomposed.Length);

        foreach (var ch in decomposed)
        {
            if (CharUnicodeInfo.GetUnicodeCategory(ch) == UnicodeCategory.NonSpacingMark)
                continue;

            if (char.IsLetterOrDigit(ch))
                builder.Append(ch);
            else if (char.IsWhiteSpace(ch))
                builder.Append(' ');
        }

        return builder.ToString().Normalize(NormalizationForm.FormC);
    }

    // La columna admite 50 caracteres y hace falta margen para el sufijo que
    // desambigua los homónimos.
    private static string Truncate(string value) =>
        value.Length <= 40 ? value : value[..40];
}
