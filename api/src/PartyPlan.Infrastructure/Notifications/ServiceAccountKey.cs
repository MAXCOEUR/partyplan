namespace PartyPlan.Infrastructure.Notifications;

using System.Security.Cryptography;
using System.Text.Json;

/// <summary>
/// Clé de compte de service Google, telle que Firebase la remet.
/// <para>
/// Lue au démarrage et validée immédiatement, clé privée comprise : découvrir un PEM
/// invalide au premier envoi, c'est le découvrir en production, un soir de soirée.
/// </para>
/// </summary>
public sealed record ServiceAccountKey(
    string ProjectId,
    string ClientEmail,
    string PrivateKeyPem)
{
    /// <summary>
    /// Lit la clé au chemin indiqué.
    /// <para>
    /// Renvoie <c>null</c> dans tous les cas d'échec, et ne lève jamais : l'absence de clé
    /// est le cas normal du développement (règle 5), et une clé cassée ne doit pas
    /// empêcher l'application de démarrer. <paramref name="probleme"/> reste <c>null</c>
    /// lorsqu'aucun chemin n'était demandé, et porte sinon de quoi corriger.
    /// </para>
    /// </summary>
    public static ServiceAccountKey? Lire(string? chemin, out string? probleme)
    {
        probleme = null;

        if (string.IsNullOrWhiteSpace(chemin))
        {
            return null;
        }

        if (!File.Exists(chemin))
        {
            probleme = $"Aucun fichier au chemin « {chemin} ».";
            return null;
        }

        JsonDocument document;
        try
        {
            document = JsonDocument.Parse(File.ReadAllText(chemin));
        }
        catch (Exception erreur) when (erreur is JsonException or IOException
                                          or UnauthorizedAccessException)
        {
            probleme = $"Le fichier « {chemin} » n'est pas un JSON lisible : {erreur.Message}";
            return null;
        }

        using (document)
        {
            var racine = document.RootElement;

            var projet = Texte(racine, "project_id");
            var courriel = Texte(racine, "client_email");
            var privee = Texte(racine, "private_key");

            var manquants = new List<string>();
            if (projet is null) { manquants.Add("project_id"); }
            if (courriel is null) { manquants.Add("client_email"); }
            if (privee is null) { manquants.Add("private_key"); }

            if (manquants.Count > 0)
            {
                probleme = $"Champs absents du fichier « {chemin} » : {string.Join(", ", manquants)}.";
                return null;
            }

            // La clé privée est éprouvée maintenant, pas au premier envoi.
            try
            {
                using var rsa = RSA.Create();
                rsa.ImportFromPem(privee);
            }
            catch (ArgumentException erreur)
            {
                probleme = $"La clé privée de « {chemin} » n'est pas un PEM valide : {erreur.Message}";
                return null;
            }

            return new ServiceAccountKey(projet!, courriel!, privee!);
        }
    }

    private static string? Texte(JsonElement racine, string nom) =>
        racine.TryGetProperty(nom, out var valeur) && valeur.ValueKind == JsonValueKind.String
            ? valeur.GetString()
            : null;
}
