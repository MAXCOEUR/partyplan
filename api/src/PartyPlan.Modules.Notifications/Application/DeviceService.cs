namespace PartyPlan.Modules.Notifications.Application;

using Microsoft.EntityFrameworkCore;
using PartyPlan.Modules.Notifications.Domain;
using PartyPlan.Modules.Notifications.Persistence;
using PartyPlan.SharedKernel.Abstractions;
using PartyPlan.SharedKernel.Contracts;
using PartyPlan.SharedKernel.Primitives;

/// <summary>
/// Appareils recevant les notifications poussées.
/// <para>
/// Implémente aussi <see cref="IPushDeviceRegistry"/>, contrat par lequel l'émetteur de
/// l'Infrastructure met un jeton au rebut sans écrire lui-même dans <c>push_devices</c>
/// (règle 6).
/// </para>
/// </summary>
public sealed class DeviceService(
    INotificationsDbContext db,
    ICurrentUser currentUser,
    IClock clock,
    IIdGenerator ids) : IPushDeviceRegistry
{
    /// <summary>Plateformes acceptées. iOS arrivera avec le portage, en V1.2.</summary>
    private static readonly string[] Plateformes = ["android", "web"];

    public static readonly DomainError JetonInvalide = DomainError.Validation(
        "device.token_required",
        "Le jeton de l'appareil est absent.");

    public static readonly DomainError PlateformeInconnue = DomainError.Validation(
        "device.unknown_platform",
        "Plateforme inconnue. Valeurs acceptées : android, web.");

    /// <summary>
    /// Enregistre l'appareil du compte appelant.
    /// <para>
    /// Idempotent sur le jeton, et réaffectant : un jeton FCM est renvoyé à chaque
    /// lancement, et le même téléphone peut changer de titulaire. Créer une ligne par
    /// appel enverrait la même notification plusieurs fois ; refuser la réaffectation
    /// laisserait les notifications d'un compte arriver chez quelqu'un d'autre.
    /// </para>
    /// </summary>
    public async Task<Result> EnregistrerAsync(
        string? token,
        string? platform,
        CancellationToken cancellationToken)
    {
        if (currentUser.UserId is not { } utilisateur)
        {
            return DomainError.Unauthenticated("auth.required", "Session requise.");
        }

        if (string.IsNullOrWhiteSpace(token))
        {
            return JetonInvalide;
        }

        var plateforme = platform?.Trim().ToLowerInvariant();

        if (plateforme is null || !Plateformes.Contains(plateforme, StringComparer.Ordinal))
        {
            return PlateformeInconnue;
        }

        var jeton = token.Trim();

        var existant = await db.PushDevices
            .FirstOrDefaultAsync(a => a.Token == jeton, cancellationToken)
            .ConfigureAwait(false);

        if (existant is null)
        {
            db.PushDevices.Add(new PushDevice
            {
                Id = ids.NewId(),
                UserId = utilisateur,
                Token = jeton,
                Platform = plateforme,
                CreatedAt = clock.UtcNow,
                LastSeenAt = clock.UtcNow,
            });
        }
        else
        {
            existant.UserId = utilisateur;
            existant.Platform = plateforme;
            existant.LastSeenAt = clock.UtcNow;
            // Un appareil qui se réenregistre est un appareil vivant : la mise au rebut
            // précédente n'a plus lieu d'être.
            existant.DisabledAt = null;
        }

        await db.SaveChangesAsync(cancellationToken).ConfigureAwait(false);

        return Result.Success();
    }

    /// <summary>
    /// Retire l'appareil. Réussit même si le jeton est inconnu : le client l'appelle à la
    /// déconnexion sans savoir ce que le serveur connaît, et un échec ici bloquerait la
    /// déconnexion pour rien.
    /// </summary>
    public async Task<Result> RetirerAsync(string token, CancellationToken cancellationToken)
    {
        if (currentUser.UserId is not { } utilisateur)
        {
            return DomainError.Unauthenticated("auth.required", "Session requise.");
        }

        var appareil = await db.PushDevices
            .FirstOrDefaultAsync(
                a => a.Token == token && a.UserId == utilisateur,
                cancellationToken)
            .ConfigureAwait(false);

        if (appareil is not null)
        {
            db.PushDevices.Remove(appareil);
            await db.SaveChangesAsync(cancellationToken).ConfigureAwait(false);
        }

        return Result.Success();
    }

    /// <inheritdoc />
    public async Task DisableAsync(string token, string raison, CancellationToken cancellationToken)
    {
        // Pas de contrôle d'appelant : c'est FCM qui déclare le jeton mort, et la
        // désactivation n'expose rien.
        var appareil = await db.PushDevices
            .FirstOrDefaultAsync(a => a.Token == token, cancellationToken)
            .ConfigureAwait(false);

        if (appareil is null || appareil.DisabledAt is not null)
        {
            return;
        }

        appareil.DisabledAt = clock.UtcNow;
        await db.SaveChangesAsync(cancellationToken).ConfigureAwait(false);
    }
}
