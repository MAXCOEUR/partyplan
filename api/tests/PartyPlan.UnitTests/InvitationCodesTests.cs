namespace PartyPlan.UnitTests;

using PartyPlan.Modules.Events.Application;
using Shouldly;
using Xunit;

/// <summary>
/// Génération des identifiants d'invitation (RG-INV-01, RG-INV-02).
/// <para>
/// Ce sont les deux clés d'accès à un événement privé : leur qualité détermine
/// directement si un tiers peut deviner l'entrée d'une soirée.
/// </para>
/// </summary>
public sealed class ShortCodeTests
{
    [Fact]
    public void Le_code_court_porte_le_prefixe_et_six_caracteres()
    {
        var code = ShortCode.Generate();

        // Format annoncé à l'utilisateur : PLAN-XXXXXX.
        code.ShouldStartWith("PLAN-");
        code.Length.ShouldBe(11);
    }

    [Fact]
    public void L_alphabet_exclut_les_caracteres_ambigus()
    {
        // RG-INV-02 : un code se dicte au téléphone et se recopie à la main. « I » et
        // « 1 », « O » et « 0 » y sont indiscernables.
        var caracteres = new HashSet<char>();

        for (var i = 0; i < 500; i++)
        {
            foreach (var caractere in ShortCode.Generate()["PLAN-".Length..])
            {
                caracteres.Add(caractere);
            }
        }

        caracteres.ShouldNotContain('I');
        caracteres.ShouldNotContain('O');
        caracteres.ShouldNotContain('0');
        caracteres.ShouldNotContain('1');
        caracteres.ShouldAllBe(c => ShortCode.Alphabet.Contains(c));
    }

    [Fact]
    public void L_alphabet_compte_trente_deux_caracteres()
    {
        // Trente-deux caractères sur six positions : environ un milliard de
        // combinaisons. Quatre positions n'en donneraient qu'un million, énumérable.
        ShortCode.Alphabet.Length.ShouldBe(32);
        ShortCode.Combinations.ShouldBeGreaterThan(1_000_000_000);
    }

    [Fact]
    public void Deux_generations_diffèrent()
    {
        var codes = new HashSet<string>();

        for (var i = 0; i < 1_000; i++)
        {
            codes.Add(ShortCode.Generate());
        }

        // Une collision sur mille tirages signalerait un générateur défaillant.
        codes.Count.ShouldBe(1_000);
    }

    [Theory]
    [InlineData("PLAN-ABC234", true)]
    [InlineData("plan-abc234", true)]
    [InlineData("PLAN ABC234", true)]
    [InlineData("ABC234", true)]
    [InlineData("PLAN-ABC23", false)]
    [InlineData("PLAN-ABC2345", false)]
    [InlineData("PLAN-ABC23I", false)]
    [InlineData("", false)]
    [InlineData(null, false)]
    public void La_normalisation_tolere_les_formes_de_saisie(string? saisie, bool valide)
    {
        // L'utilisateur recopie « plan abc234 » ou « ABC234 » : refuser ces formes
        // ferait échouer l'entrée pour une raison qu'il ne comprendrait pas.
        ShortCode.TryNormalize(saisie, out var normalise).ShouldBe(valide);

        if (valide)
        {
            normalise.ShouldBe("PLAN-ABC234");
        }
    }
}

public sealed class InviteTokenTests
{
    [Fact]
    public void Le_jeton_porte_au_moins_cent_vingt_huit_bits_d_entropie()
    {
        var jeton = InviteToken.Generate();

        // RG-INV-01 : le lien est la seule protection d'un événement privé partagé par
        // messagerie. Trente-deux caractères base64url valent 192 bits.
        InviteToken.EntropyBits.ShouldBeGreaterThanOrEqualTo(128);
        jeton.Length.ShouldBeGreaterThanOrEqualTo(22);
    }

    [Fact]
    public void Le_jeton_est_utilisable_dans_une_url_sans_encodage()
    {
        for (var i = 0; i < 200; i++)
        {
            var jeton = InviteToken.Generate();

            // Un jeton contenant « + », « / » ou « = » serait réencodé au partage et
            // deviendrait invalide au collage.
            jeton.ShouldAllBe(c => char.IsAsciiLetterOrDigit(c) || c == '-' || c == '_');
        }
    }

    [Fact]
    public void Deux_jetons_diffèrent()
    {
        var jetons = new HashSet<string>();

        for (var i = 0; i < 1_000; i++)
        {
            jetons.Add(InviteToken.Generate());
        }

        jetons.Count.ShouldBe(1_000);
    }
}
