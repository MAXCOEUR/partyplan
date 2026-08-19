namespace PartyPlan.UnitTests;

using System.Text;
using PartyPlan.Modules.Auth.Application;
using Shouldly;
using Xunit;

/// <summary>
/// Vecteurs de test officiels de la RFC 6238, annexe B.
/// <para>
/// Ces vecteurs sont la raison pour laquelle l'algorithme est implémenté ici plutôt
/// qu'emprunté : ils prouvent la conformité, ce qu'aucune dépendance ne fait à notre
/// place. Un code refusé par Google Authenticator est un compte inaccessible.
/// </para>
/// </summary>
public sealed class TotpRfcVectorsTests
{
    /// <summary>Secret des vecteurs de la RFC : « 12345678901234567890 » en ASCII.</summary>
    private static readonly byte[] SecretRfc = Encoding.ASCII.GetBytes("12345678901234567890");

    [Theory]
    [InlineData(59L, "287082")]
    [InlineData(1111111109L, "081804")]
    [InlineData(1111111111L, "050471")]
    [InlineData(1234567890L, "005924")]
    [InlineData(2000000000L, "279037")]
    [InlineData(20000000000L, "353130")]
    public void Les_vecteurs_de_la_rfc_6238_sont_reproduits(long secondes, string attendu)
    {
        var instant = DateTimeOffset.FromUnixTimeSeconds(secondes);

        Totp.Compute(SecretRfc, instant).ShouldBe(attendu);
    }

    [Fact]
    public void Le_code_change_a_chaque_pas_de_trente_secondes()
    {
        // Instant aligné sur une frontière de pas : 1 700 000 010 est un multiple de 30.
        // Partir d'un instant quelconque ferait franchir la frontière avant la 29e
        // seconde, et le test échouerait pour une raison étrangère à ce qu'il vérifie.
        var origine = DateTimeOffset.FromUnixTimeSeconds(1_700_000_010);

        var premier = Totp.Compute(SecretRfc, origine);
        var meme = Totp.Compute(SecretRfc, origine.AddSeconds(29));
        var suivant = Totp.Compute(SecretRfc, origine.AddSeconds(30));

        meme.ShouldBe(premier);
        suivant.ShouldNotBe(premier);
    }
}

public sealed class TotpVerificationTests
{
    private static readonly byte[] Secret = Encoding.ASCII.GetBytes("12345678901234567890");
    private static readonly DateTimeOffset Maintenant = DateTimeOffset.FromUnixTimeSeconds(1_700_000_000);

    [Fact]
    public void Le_code_du_pas_courant_est_accepte()
    {
        Totp.Verify(Secret, Totp.Compute(Secret, Maintenant), Maintenant).ShouldBeTrue();
    }

    [Fact]
    public void Le_code_du_pas_precedent_est_accepte()
    {
        // Les horloges de téléphone dérivent : refuser le pas précédent produirait des
        // échecs inexplicables pour l'utilisateur.
        var precedent = Totp.Compute(Secret, Maintenant.AddSeconds(-30));

        Totp.Verify(Secret, precedent, Maintenant).ShouldBeTrue();
    }

    [Fact]
    public void Le_code_du_pas_suivant_est_accepte()
    {
        var suivant = Totp.Compute(Secret, Maintenant.AddSeconds(30));

        Totp.Verify(Secret, suivant, Maintenant).ShouldBeTrue();
    }

    [Fact]
    public void Un_code_de_deux_pas_d_ecart_est_refuse()
    {
        // La tolérance s'arrête à un pas : l'élargir n'apporterait qu'une fenêtre
        // d'attaque plus large.
        var trop_vieux = Totp.Compute(Secret, Maintenant.AddSeconds(-90));

        Totp.Verify(Secret, trop_vieux, Maintenant).ShouldBeFalse();
    }

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("   ")]
    [InlineData("12345")]
    [InlineData("1234567")]
    [InlineData("12345a")]
    [InlineData("abcdef")]
    public void Un_code_malforme_est_refuse_sans_lever(string? code)
    {
        Totp.Verify(Secret, code, Maintenant).ShouldBeFalse();
    }

    [Fact]
    public void Les_espaces_de_saisie_sont_tolerees()
    {
        // Les applications affichent « 123 456 » : recopier l'espace ne doit pas échouer.
        var code = Totp.Compute(Secret, Maintenant);
        var avecEspace = $"{code[..3]} {code[3..]}";

        Totp.Verify(Secret, avecEspace, Maintenant).ShouldBeTrue();
    }

    [Fact]
    public void Un_secret_different_refuse_le_code()
    {
        var autre = Totp.GenerateSecret();

        Totp.Verify(autre, Totp.Compute(Secret, Maintenant), Maintenant).ShouldBeFalse();
    }

    [Fact]
    public void Le_secret_genere_fait_cent_soixante_bits()
    {
        // Longueur recommandée par la RFC 4226.
        Totp.GenerateSecret().Length.ShouldBe(20);
        Totp.GenerateSecret().ShouldNotBe(Totp.GenerateSecret());
    }

    [Fact]
    public void L_uri_otpauth_porte_tous_les_parametres_attendus()
    {
        var uri = Totp.BuildUri("PartyPlan", "maxence@partyplan.fr", Secret);

        uri.ShouldStartWith("otpauth://totp/PartyPlan:maxence%40partyplan.fr?");
        uri.ShouldContain($"secret={Base32.Encode(Secret)}");
        uri.ShouldContain("issuer=PartyPlan");
        uri.ShouldContain("algorithm=SHA1");
        uri.ShouldContain("digits=6");
        uri.ShouldContain("period=30");
    }
}

public sealed class Base32Tests
{
    [Theory]
    [InlineData("", "")]
    [InlineData("f", "MY")]
    [InlineData("fo", "MZXQ")]
    [InlineData("foo", "MZXW6")]
    [InlineData("foob", "MZXW6YQ")]
    [InlineData("fooba", "MZXW6YTB")]
    [InlineData("foobar", "MZXW6YTBOI")]
    public void Les_vecteurs_de_la_rfc_4648_sont_reproduits(string source, string attendu)
    {
        Base32.Encode(Encoding.ASCII.GetBytes(source)).ShouldBe(attendu);
    }

    [Fact]
    public void Le_decodage_est_l_inverse_de_l_encodage()
    {
        var secret = Totp.GenerateSecret();

        Base32.TryDecode(Base32.Encode(secret), out var decode).ShouldBeTrue();
        decode.ShouldBe(secret);
    }

    [Theory]
    [InlineData("MZXW 6YTB OI")]
    [InlineData("MZXW-6YTB-OI")]
    [InlineData("mzxw6ytboi")]
    [InlineData("MZXW6YTBOI======")]
    public void La_saisie_manuelle_est_toleree(string saisie)
    {
        // Un secret recopié à la main porte des espaces, des tirets, et parfois du
        // remplissage : refuser ces formes ferait échouer l'enrôlement sans explication.
        Base32.TryDecode(saisie, out var decode).ShouldBeTrue();
        Encoding.ASCII.GetString(decode).ShouldBe("foobar");
    }

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("   ")]
    [InlineData("0189!")]
    public void Une_valeur_invalide_est_refusee(string? saisie)
    {
        Base32.TryDecode(saisie, out _).ShouldBeFalse();
    }
}
