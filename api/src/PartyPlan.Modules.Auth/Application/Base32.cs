namespace PartyPlan.Modules.Auth.Application;

/// <summary>
/// Encodage base32 selon la RFC 4648, sans remplissage.
/// <para>
/// Format imposé par les applications d'authentification : un secret TOTP se saisit à la
/// main lorsque le QR code ne peut pas être scanné, et l'alphabet base32 évite les
/// confusions entre caractères.
/// </para>
/// </summary>
public static class Base32
{
    private const string Alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567";

    public static string Encode(ReadOnlySpan<byte> data)
    {
        if (data.IsEmpty)
        {
            return string.Empty;
        }

        var sortie = new System.Text.StringBuilder((data.Length * 8 + 4) / 5);
        var tampon = 0;
        var bits = 0;

        foreach (var octet in data)
        {
            tampon = (tampon << 8) | octet;
            bits += 8;

            while (bits >= 5)
            {
                sortie.Append(Alphabet[(tampon >> (bits - 5)) & 31]);
                bits -= 5;
            }
        }

        if (bits > 0)
        {
            sortie.Append(Alphabet[(tampon << (5 - bits)) & 31]);
        }

        return sortie.ToString();
    }

    /// <summary>
    /// Décode une chaîne base32. Les espaces et le remplissage sont tolérés : un
    /// utilisateur qui recopie un secret y ajoute souvent des espaces.
    /// </summary>
    public static bool TryDecode(string? value, out byte[] data)
    {
        data = [];

        if (string.IsNullOrWhiteSpace(value))
        {
            return false;
        }

        var normalise = value.Replace(" ", string.Empty, StringComparison.Ordinal)
            .Replace("-", string.Empty, StringComparison.Ordinal)
            .TrimEnd('=')
            .ToUpperInvariant();

        var octets = new List<byte>(normalise.Length * 5 / 8);
        var tampon = 0;
        var bits = 0;

        foreach (var caractere in normalise)
        {
            var index = Alphabet.IndexOf(caractere, StringComparison.Ordinal);
            if (index < 0)
            {
                return false;
            }

            tampon = (tampon << 5) | index;
            bits += 5;

            if (bits >= 8)
            {
                octets.Add((byte)((tampon >> (bits - 8)) & 255));
                bits -= 8;
            }
        }

        data = [.. octets];

        return data.Length > 0;
    }
}
