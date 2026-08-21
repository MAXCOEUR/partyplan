namespace PartyPlan.SharedKernel.Contracts;

using PartyPlan.SharedKernel.Primitives;

/// <summary>
/// Stockage des images partagées dans la discussion d'un événement.
/// <para>
/// L'image est réduite et réencodée avant d'être écrite. Ce n'est pas seulement une
/// question de poids : décoder puis réencoder supprime les métadonnées EXIF, dont la
/// géolocalisation qu'un téléphone inscrit dans chaque photo (NF-SEC-09). Servir le
/// fichier d'origine publierait le lieu de la prise de vue à tous les membres de
/// l'événement.
/// </para>
/// <para>
/// La compression a lieu ici plutôt que sur le client : elle s'applique alors quel que
/// soit l'appareil, et un client ancien ou bavard ne peut pas contourner le retrait des
/// métadonnées.
/// </para>
/// </summary>
public interface IEventImageStorage
{
    /// <summary>
    /// Côté le plus long de l'image conservée, en pixels. Au-delà, on stocke des
    /// détails qu'aucun écran de téléphone n'affiche.
    /// </summary>
    const int MaxSide = 1600;

    /// <summary>Taille maximale acceptée à l'envoi, en octets.</summary>
    const long MaxBytes = 12 * 1024 * 1024;

    /// <summary>
    /// Enregistre l'image et renvoie son adresse publique. L'adresse porte une
    /// empreinte du contenu : elle peut être mise en cache durablement.
    /// </summary>
    Task<Result<string>> StoreAsync(
        Guid eventId,
        Stream content,
        string declaredContentType,
        CancellationToken cancellationToken);
}
