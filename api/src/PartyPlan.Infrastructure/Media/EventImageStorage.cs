namespace PartyPlan.Infrastructure.Media;

using System.Globalization;
using System.Security.Cryptography;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using PartyPlan.SharedKernel.Contracts;
using PartyPlan.SharedKernel.Primitives;
using SkiaSharp;

/// <summary>
/// Images de la discussion (EF-MSG-02).
/// <para>
/// Même principe que les photos de profil, à deux différences près : l'image n'est pas
/// recadrée au carré — une photo de soirée se regarde entière — et une seule taille est
/// produite, celle qui suffit à un écran de téléphone.
/// </para>
/// </summary>
public sealed class EventImageStorage(
    IOptions<MediaOptions> options,
    ILogger<EventImageStorage> logger) : IEventImageStorage
{
    /// <summary>
    /// Types acceptés. Le type déclaré ne fait pas foi : c'est le décodage effectif qui
    /// valide le fichier, et un exécutable renommé en .png échoue là.
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
        "message.image_unsupported_type",
        "Formats acceptés : JPEG, PNG, WebP et HEIC.");

    public static readonly DomainError NotAnImage = DomainError.Validation(
        "message.not_an_image",
        "Ce fichier n'est pas une image lisible.");

    public static readonly DomainError TooLarge = DomainError.Validation(
        "message.image_too_large",
        "L'image ne doit pas dépasser 12 Mo.");

    public async Task<Result<string>> StoreAsync(
        Guid eventId,
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

        if (tampon.Length > IEventImageStorage.MaxBytes)
        {
            return TooLarge;
        }

        tampon.Position = 0;

        using var original = SKBitmap.Decode(tampon);
        if (original is null)
        {
            return NotAnImage;
        }

        var empreinte = Convert.ToHexString(SHA256.HashData(tampon.ToArray()))[..16]
            .ToLower(CultureInfo.InvariantCulture);

        var repertoire = Path.Combine(
            options.Value.RootPath,
            "events",
            eventId.ToString());

        Directory.CreateDirectory(repertoire);

        using var reduite = Reduire(original, IEventImageStorage.MaxSide);
        using var image = SKImage.FromBitmap(reduite);

        // Qualité 82 : le seuil au-delà duquel un écran de téléphone ne distingue plus
        // rien, pour un fichier trois à dix fois plus léger que l'original.
        using var donnees = image.Encode(SKEncodedImageFormat.Webp, 82);

        var chemin = Path.Combine(repertoire, $"{empreinte}.webp");

        // Une même image envoyée deux fois porte la même empreinte : la réécrire
        // n'apporterait rien.
        if (!File.Exists(chemin))
        {
            await using var fichier = File.Create(chemin);
            donnees.SaveTo(fichier);
        }

        logger.LogInformation(
            "Image de discussion enregistrée pour l'événement {Evenement} ({Octets} octets)",
            eventId,
            donnees.Size);

        return $"{options.Value.PublicBaseUrl}/events/{eventId}/{empreinte}.webp";
    }

    /// <summary>
    /// Met à l'échelle en conservant les proportions. Une image déjà plus petite que la
    /// limite est réencodée sans être agrandie : l'étirer n'ajouterait aucun détail et
    /// alourdirait le fichier.
    /// </summary>
    private static SKBitmap Reduire(SKBitmap source, int coteMaximal)
    {
        var plusGrandCote = Math.Max(source.Width, source.Height);
        var facteur = plusGrandCote <= coteMaximal
            ? 1.0
            : coteMaximal / (double)plusGrandCote;

        var largeur = Math.Max(1, (int)Math.Round(source.Width * facteur));
        var hauteur = Math.Max(1, (int)Math.Round(source.Height * facteur));

        var resultat = new SKBitmap(largeur, hauteur);
        source.ScalePixels(
            resultat,
            new SKSamplingOptions(SKFilterMode.Linear, SKMipmapMode.Linear));

        return resultat;
    }
}
