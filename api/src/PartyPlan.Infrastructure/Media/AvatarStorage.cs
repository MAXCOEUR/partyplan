namespace PartyPlan.Infrastructure.Media;

using System.Globalization;
using System.Security.Cryptography;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using PartyPlan.SharedKernel.Contracts;
using PartyPlan.SharedKernel.Primitives;
using SkiaSharp;

public sealed class MediaOptions
{
    public const string SectionName = "Media";

    /// <summary>Racine de stockage des fichiers. Servie par le domaine statique.</summary>
    public string RootPath { get; set; } = "/var/lib/partyplan/media";

    /// <summary>Préfixe public des adresses servies.</summary>
    public string PublicBaseUrl { get; set; } = "http://localhost:5080/media";
}

/// <summary>
/// Stockage des photos de profil (RG-USR-01, RG-USR-03, NF-SEC-09).
/// <para>
/// SkiaSharp est retenu plutôt qu'ImageSharp : licence MIT, sans redevance commerciale
/// au-delà d'un seuil de chiffre d'affaires — condition nécessaire pour un produit
/// destiné à être vendu.
/// </para>
/// <para>
/// Le réencodage n'est pas seulement un redimensionnement : décoder puis réencoder
/// supprime l'intégralité des métadonnées, dont la géolocalisation EXIF qu'un téléphone
/// inscrit dans chaque photo. Conserver l'image d'origine publierait le lieu de la prise
/// de vue.
/// </para>
/// </summary>
public sealed class AvatarStorage(
    IOptions<MediaOptions> options,
    ILogger<AvatarStorage> logger) : IAvatarStorage
{
    /// <summary>
    /// Types acceptés (RG-USR-01). Le type déclaré ne fait pas foi : c'est le décodage
    /// effectif qui valide le fichier.
    /// </summary>
    private static readonly string[] AllowedTypes =
    [
        "image/jpeg",
        "image/png",
        "image/webp",
        "image/heic",
        "image/heif",
    ];

    public static readonly DomainError UnsupportedType = DomainError.Validation(
        "avatar.unsupported_type",
        "Formats acceptés : JPEG, PNG, WebP et HEIC.");

    public static readonly DomainError NotAnImage = DomainError.Validation(
        "avatar.not_an_image",
        "Ce fichier n'est pas une image lisible.");

    public async Task<Result<string>> StoreAsync(
        Guid userId,
        Stream content,
        string declaredContentType,
        CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(content);

        if (!AllowedTypes.Contains(declaredContentType, StringComparer.OrdinalIgnoreCase))
        {
            return UnsupportedType;
        }

        using var tampon = new MemoryStream();
        await content.CopyToAsync(tampon, cancellationToken).ConfigureAwait(false);

        if (tampon.Length > IAvatarStorage.MaxBytes)
        {
            return DomainError.Validation("avatar.too_large", "L'image ne doit pas dépasser 5 Mo.");
        }

        tampon.Position = 0;

        // Le décodage est la véritable validation : un exécutable renommé en .png
        // échoue ici, quel que soit le type déclaré (NF-SEC-09).
        using var original = SKBitmap.Decode(tampon);
        if (original is null)
        {
            return NotAnImage;
        }

        var empreinte = Convert.ToHexString(SHA256.HashData(tampon.ToArray()))[..16]
            .ToLower(CultureInfo.InvariantCulture);

        var repertoire = Path.Combine(options.Value.RootPath, "avatars", userId.ToString());
        Directory.CreateDirectory(repertoire);

        // Les anciennes versions sont retirées : l'adresse portant une empreinte, elles
        // ne seraient plus jamais servies et s'accumuleraient.
        foreach (var ancien in Directory.EnumerateFiles(repertoire, "*.webp"))
        {
            File.Delete(ancien);
        }

        foreach (var taille in IAvatarStorage.Sizes)
        {
            using var redimensionne = Recadrer(original, taille);
            using var image = SKImage.FromBitmap(redimensionne);
            using var donnees = image.Encode(SKEncodedImageFormat.Webp, 82);

            var chemin = Path.Combine(repertoire, $"{empreinte}-{taille}.webp");
            await using var fichier = File.Create(chemin);
            donnees.SaveTo(fichier);
        }

        logger.LogInformation("Photo de profil enregistrée pour {Utilisateur}", userId);

        return $"{options.Value.PublicBaseUrl}/avatars/{userId}/{empreinte}-512.webp";
    }

    public Task DeleteAsync(Guid userId, CancellationToken cancellationToken)
    {
        var repertoire = Path.Combine(options.Value.RootPath, "avatars", userId.ToString());

        if (Directory.Exists(repertoire))
        {
            Directory.Delete(repertoire, recursive: true);
            logger.LogInformation("Photo de profil supprimée pour {Utilisateur}", userId);
        }

        return Task.CompletedTask;
    }

    /// <summary>
    /// Recadre au carré depuis le centre, puis met à l'échelle. Un simple
    /// redimensionnement déformerait un portrait en paysage.
    /// </summary>
    private static SKBitmap Recadrer(SKBitmap source, int taille)
    {
        var cote = Math.Min(source.Width, source.Height);
        var origineX = (source.Width - cote) / 2;
        var origineY = (source.Height - cote) / 2;

        using var carre = new SKBitmap(cote, cote);
        source.ExtractSubset(carre, new SKRectI(origineX, origineY, origineX + cote, origineY + cote));

        var resultat = new SKBitmap(taille, taille);
        carre.ScalePixels(resultat, new SKSamplingOptions(SKFilterMode.Linear, SKMipmapMode.Linear));

        return resultat;
    }
}
