namespace Kairos.Application.Common.Exceptions;

/// <summary>
/// Las credenciales eran correctas, pero la cuenta todavía no puede entrar.
///
/// Se distingue de <see cref="UnauthorizedAccessException"/> a propósito: para
/// el cliente no es lo mismo "te equivocaste de contraseña" que "tu cuenta
/// espera aprobación", y antes ambos casos llegaban como un 401 indistinguible.
/// </summary>
public class AccountNotApprovedException(string accountStatus, string message)
    : Exception(message)
{
    /// <summary>"pending" o "rejected".</summary>
    public string AccountStatus { get; } = accountStatus;
}
