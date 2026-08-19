namespace PartyPlan.SharedKernel.Contracts;

using PartyPlan.SharedKernel.Primitives;

/// <summary>
/// Stockage des photos de profil. Implémenté par l'Infrastructure.
/// <para>
/// L'implémentation redimensionne, convertit en WebP et retire les métadonnées EXIF,
/// dont la géolocalisation : une photo prise au téléphone porte les coordonnées du lieu
/// de la prise de vue (RG-USR-01, NF-SEC-09).
/// </para>
/// </summary>
public interface IAvatarStorage
{
    /// <summary>Tailles produites, en pixels (RG-USR-01).</summary>
    static readonly int[] Sizes = [512, 128, 48];

    /// <summary>Taille maximale acceptée, en octets.</summary>
    const long MaxBytes = 5 * 1024 * 1024;

    /// <summary>
    /// Enregistre l'image et renvoie l'adresse publique de la taille de référence.
    /// L'adresse contient une empreinte du contenu, afin d'être mise en cache
    /// durablement sans risque d'afficher une version obsolète (RG-USR-03).
    /// </summary>
    Task<Result<string>> StoreAsync(
        Guid userId,
        Stream content,
        string declaredContentType,
        CancellationToken cancellationToken);

    Task DeleteAsync(Guid userId, CancellationToken cancellationToken);
}
