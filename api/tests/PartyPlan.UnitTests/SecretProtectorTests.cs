namespace PartyPlan.UnitTests;

using Microsoft.Extensions.Options;
using PartyPlan.Infrastructure.Security;
using Shouldly;
using Xunit;

/// <summary>
/// Chiffrement des secrets stockés. Un défaut ici compromet le second facteur de tous
/// les comptes en cas de fuite de base.
/// </summary>
public sealed class SecretProtectorTests
{
    private static readonly byte[] Cle = Convert.FromBase64String(
        Convert.ToBase64String(System.Text.Encoding.ASCII.GetBytes("une-cle-de-test-de-32-octets!!!!")));

    private static AesGcmSecretProtector Protecteur(string? cle = null) =>
        new(Options.Create(new SecurityOptions
        {
            EncryptionKey = cle ?? Convert.ToBase64String(Cle),
        }));

    [Fact]
    public void Un_secret_chiffre_se_relit_a_l_identique()
    {
        var protecteur = Protecteur();
        var secret = new byte[] { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 };

        var protege = protecteur.Protect(secret);

        protecteur.TryUnprotect(protege, out var relu).ShouldBeTrue();
        relu.ShouldBe(secret);
    }

    [Fact]
    public void Le_texte_chiffre_ne_contient_pas_le_secret()
    {
        var protecteur = Protecteur();
        var secret = System.Text.Encoding.ASCII.GetBytes("SECRETTOTP1234567890");

        var protege = protecteur.Protect(secret);

        protege.ShouldNotContain("SECRETTOTP");
        Convert.FromBase64String(protege.Split('.')[2]).ShouldNotBe(secret);
    }

    [Fact]
    public void Deux_chiffrements_du_meme_secret_different()
    {
        // Nonce aléatoire : sans lui, deux comptes partageant un secret seraient
        // identifiables dans une fuite de base.
        var protecteur = Protecteur();
        var secret = new byte[20];

        protecteur.Protect(secret).ShouldNotBe(protecteur.Protect(secret));
    }

    [Fact]
    public void Une_alteration_du_texte_chiffre_est_detectee()
    {
        var protecteur = Protecteur();
        var protege = protecteur.Protect(new byte[] { 42, 42, 42 });

        var parties = protege.Split('.');
        var chiffre = Convert.FromBase64String(parties[2]);
        chiffre[0] ^= 0xFF;
        parties[2] = Convert.ToBase64String(chiffre);

        // AES-GCM authentifie : une altération est refusée au lieu de produire des
        // octets arbitraires, qui feraient perdre l'accès sans explication.
        protecteur.TryUnprotect(string.Join('.', parties), out _).ShouldBeFalse();
    }

    [Fact]
    public void Une_cle_differente_ne_dechiffre_pas()
    {
        var protege = Protecteur().Protect(new byte[] { 7, 7, 7 });

        var autre = Protecteur(Convert.ToBase64String(
            System.Text.Encoding.ASCII.GetBytes("une-AUTRE-cle-de-32-octets!!!!!!")));

        autre.TryUnprotect(protege, out _).ShouldBeFalse();
    }

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("pas-un-format")]
    [InlineData("v2.AAAA.AAAA.AAAA")]
    [InlineData("v1.pas-du-base64.AAAA.AAAA")]
    [InlineData("v1.AAAA.AAAA")]
    public void Une_valeur_malformee_est_refusee_sans_lever(string? valeur)
    {
        Protecteur().TryUnprotect(valeur, out _).ShouldBeFalse();
    }

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("   ")]
    public void Une_cle_absente_empeche_la_construction(string? cle)
    {
        // Construction directe, sans passer par l'assistant : son opérateur `??`
        // remplacerait une clé nulle par la clé valide et masquerait le cas testé.
        //
        // Échec au démarrage plutôt qu'à la première écriture : une API qui démarre puis
        // échoue sur l'enrôlement du premier utilisateur est plus difficile à
        // diagnostiquer.
        Should.Throw<InvalidOperationException>(
                () => new AesGcmSecretProtector(
                    Options.Create(new SecurityOptions { EncryptionKey = cle! })))
            .Message.ShouldContain("EncryptionKey");
    }

    [Fact]
    public void Une_cle_de_mauvaise_longueur_est_refusee()
    {
        Should.Throw<InvalidOperationException>(
                () => Protecteur(Convert.ToBase64String(new byte[16])))
            .Message.ShouldContain("32 octets");
    }

    [Fact]
    public void Une_cle_qui_n_est_pas_du_base64_est_refusee()
    {
        Should.Throw<InvalidOperationException>(() => Protecteur("pas du base64 !"))
            .Message.ShouldContain("base64");
    }
}
