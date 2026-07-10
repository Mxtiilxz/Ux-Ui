namespace Kairos.Application.Features.Matching;

// Valores compartidos de Quick Match. El mensaje por defecto se usa cuando la
// empresa todavía no personalizó su plantilla de contacto.
// Placeholders soportados: {nombre} (candidato), {empresa} (nombre de la
// empresa) y {competencias} (competencias coincidentes, separadas por coma).
public static class QuickMatchDefaults
{
    public const string MessageTemplate =
        "Hola {nombre}, te contactamos desde {empresa}. Vimos que dominas {competencias} " +
        "y nos encantaría conversar contigo sobre una oportunidad de práctica. ¿Te interesaría?";
}
