// ============================================================
//  Kairos.Infrastructure / Services / CurriculumGeneratorService.cs
// ============================================================

using Kairos.Application.Common.Interfaces;
using Kairos.Domain.Entities;
using QuestPDF.Fluent;
using QuestPDF.Helpers;
using QuestPDF.Infrastructure;

namespace Kairos.Infrastructure.Services;

/// <summary>
/// Currículum en formato clásico de una columna: nombre y contacto arriba,
/// después perfil, formación, experiencia y competencias.
///
/// Antes el documento se armaba agrupando <c>user_activities</c>, la bitácora
/// de uso de la red social. El resultado era un listado de "publicó", "comentó"
/// y "dio me gusta" — un registro de actividad que ningún empleador puede leer
/// como currículum, y que además salía casi vacío porque solo las publicaciones
/// escribían en esa tabla.
/// </summary>
public class CurriculumGenerator : ICurriculumGenerator
{
    static CurriculumGenerator()
    {
        QuestPDF.Settings.License = LicenseType.Community;
    }

    public byte[] Generate(CurriculumData data)
    {
        var user = data.User;

        return Document.Create(container =>
        {
            container.Page(page =>
            {
                page.Size(PageSizes.A4);
                page.Margin(48);
                page.DefaultTextStyle(t => t.FontSize(10.5f).FontFamily("Arial"));

                page.Header().Column(col =>
                {
                    col.Item().AlignCenter().Text(user.FullName.ToUpperInvariant())
                        .FontSize(20).Bold().LetterSpacing(0.06f);

                    var contact = new[] { user.Email, user.Institution }
                        .Where(part => !string.IsNullOrWhiteSpace(part));

                    col.Item().AlignCenter().PaddingTop(4)
                        .Text(string.Join("  ·  ", contact))
                        .FontSize(10).FontColor(Colors.Grey.Darken1);

                    col.Item().PaddingTop(10)
                        .LineHorizontal(1.2f).LineColor(Colors.Black);
                });

                page.Content().PaddingTop(14).Column(col =>
                {
                    if (!string.IsNullOrWhiteSpace(user.Bio))
                    {
                        Section(col, "PERFIL");
                        col.Item().PaddingTop(4).Text(user.Bio!).LineHeight(1.35f);
                    }

                    if (data.Education.Count > 0)
                    {
                        Section(col, "FORMACIÓN");
                        foreach (var entry in data.Education) Entry(col, entry);
                    }

                    if (data.Experience.Count > 0)
                    {
                        Section(col, "EXPERIENCIA");
                        foreach (var entry in data.Experience) Entry(col, entry);
                    }

                    if (data.Skills.Count > 0)
                    {
                        Section(col, "COMPETENCIAS");

                        // Agrupadas por categoría: un bloque de veinte nombres
                        // seguidos no se lee, y separarlas dice además de qué
                        // tipo es cada una.
                        foreach (var group in data.Skills.GroupBy(s => s.Category))
                        {
                            col.Item().PaddingTop(4).Text(text =>
                            {
                                text.Span($"{CategoryLabel(group.Key)}: ").SemiBold();
                                text.Span(string.Join(", ", group.Select(s => s.Name)));
                            });
                        }
                    }

                    // Un currículum sin nada que contar es peor que ninguno: se
                    // dice qué falta y dónde completarlo, en vez de entregar una
                    // hoja con solo el nombre.
                    if (data.Education.Count == 0 &&
                        data.Experience.Count == 0 &&
                        data.Skills.Count == 0)
                    {
                        col.Item().PaddingTop(20).Text(
                            "Este currículum todavía no tiene contenido. Agrega tu " +
                            "formación, tu experiencia y tus competencias desde tu " +
                            "perfil en Kairos y vuelve a descargarlo.")
                            .FontColor(Colors.Grey.Darken1).Italic();
                    }
                });

                page.Footer().AlignCenter().Text(
                    $"Generado en Kairos · {DateTime.Now:dd-MM-yyyy}")
                    .FontSize(8).FontColor(Colors.Grey.Medium);
            });
        }).GeneratePdf();
    }

    private static void Section(ColumnDescriptor col, string title)
    {
        col.Item().PaddingTop(14).Text(title)
            .FontSize(11).Bold().LetterSpacing(0.08f);
        col.Item().PaddingTop(2).LineHorizontal(0.6f).LineColor(Colors.Grey.Medium);
    }

    private static void Entry(ColumnDescriptor col, CvEntry entry)
    {
        col.Item().PaddingTop(8).Row(row =>
        {
            row.RelativeItem().Column(inner =>
            {
                inner.Item().Text(entry.Title).SemiBold();

                if (!string.IsNullOrWhiteSpace(entry.Organization))
                    inner.Item().Text(entry.Organization)
                        .FontColor(Colors.Grey.Darken1);

                if (!string.IsNullOrWhiteSpace(entry.Detail))
                    inner.Item().PaddingTop(2).Text(entry.Detail!).LineHeight(1.3f);
            });

            row.ConstantItem(90).AlignRight().Text(Period(entry))
                .FontColor(Colors.Grey.Darken1);
        });
    }

    /// <summary>Sin año de término se entiende que sigue en curso.</summary>
    private static string Period(CvEntry entry) => (entry.StartYear, entry.EndYear) switch
    {
        (null, null)         => string.Empty,
        (null, var end)      => end.ToString()!,
        (var start, null)    => $"{start} — Actual",
        var (start, end)     => start == end ? start.ToString()! : $"{start} — {end}",
    };

    private static string CategoryLabel(SkillCategory category) => category switch
    {
        SkillCategory.Language   => "Idiomas",
        SkillCategory.Experience => "Experiencia",
        _                        => "Técnicas",
    };
}
