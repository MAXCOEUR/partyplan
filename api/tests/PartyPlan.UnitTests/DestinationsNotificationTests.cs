namespace PartyPlan.UnitTests;

using System.Reflection;
using System.Text.Json;
using PartyPlan.SharedKernel.Contracts;
using Shouldly;
using Xunit;

/// <summary>
/// Contrat des destinations de notification.
/// <para>
/// La moitié serveur de la vérification. L'application Flutter lit le même fichier et
/// s'assure qu'elle sait ouvrir chacune de ces adresses ; sans ce fichier, les deux
/// moitiés ne peuvent pas se parler — c'est ainsi que <c>/events/{id}/courses</c> a pu
/// être envoyé pendant des semaines vers une route inexistante.
/// </para>
/// </summary>
public sealed class DestinationsNotificationTests
{
    private static readonly Guid Soiree = Guid.Parse("01a023e7-9cb7-714d-8383-b4959de88ea8");

    [Fact]
    public void Le_fichier_de_contrat_reprend_exactement_les_motifs()
    {
        // Ajouter une destination sans mettre le fichier à jour laisserait l'application
        // ignorer la nouvelle route, et le lien retomberait sur la page d'erreur.
        var fichier = JsonSerializer.Deserialize<string[]>(
            File.ReadAllText(CheminDuContrat()))!;

        fichier.ShouldBe([.. DestinationsNotification.Motifs], ignoreOrder: true);
    }

    [Fact]
    public void Chaque_destination_produite_correspond_a_un_motif()
    {
        // Le motif est la forme que l'application déclare ; la destination est ce que le
        // serveur envoie. Une destination hors motif est un lien mort.
        var motifs = DestinationsNotification.Motifs
            .Select(m => m.Replace("{eventId}", Soiree.ToString(), StringComparison.Ordinal))
            .ToHashSet();

        foreach (var (nom, destination) in DestinationsProduites())
        {
            motifs.ShouldContain(destination, $"{nom} produit une adresse hors contrat.");
        }
    }

    [Fact]
    public void Toutes_les_destinations_du_contrat_sont_produites()
    {
        // Un motif que plus personne n'envoie est une route que l'application entretient
        // pour rien, et une ligne de contrat qui ne protège plus de rien.
        var produites = DestinationsProduites().Select(d => d.Destination).ToHashSet();

        foreach (var motif in DestinationsNotification.Motifs)
        {
            produites.ShouldContain(
                motif.Replace("{eventId}", Soiree.ToString(), StringComparison.Ordinal),
                $"{motif} ne correspond à aucune destination produite.");
        }
    }

    /// <summary>
    /// Appelle chaque fabrique de destination par réflexion.
    /// <para>
    /// Par réflexion et non par une liste écrite à la main : une liste recopiée oublie
    /// la fabrique ajoutée le mois suivant, et le test passerait sans la couvrir.
    /// </para>
    /// </summary>
    private static IEnumerable<(string Nom, string Destination)> DestinationsProduites() =>
        typeof(DestinationsNotification)
            .GetMethods(BindingFlags.Public | BindingFlags.Static)
            .Where(m => m.ReturnType == typeof(string)
                        && m.GetParameters() is [{ ParameterType: var t }] && t == typeof(Guid))
            .Select(m => (m.Name, (string)m.Invoke(null, [Soiree])!));

    /// <summary>Remonte du répertoire d'exécution jusqu'à la racine du dépôt.</summary>
    private static string CheminDuContrat()
    {
        var repertoire = new DirectoryInfo(AppContext.BaseDirectory);

        while (repertoire is not null)
        {
            var candidat = Path.Combine(
                repertoire.FullName, "docs", "api", "destinations-notification.json");

            if (File.Exists(candidat))
            {
                return candidat;
            }

            repertoire = repertoire.Parent;
        }

        throw new FileNotFoundException(
            "docs/api/destinations-notification.json introuvable depuis "
            + AppContext.BaseDirectory);
    }
}
