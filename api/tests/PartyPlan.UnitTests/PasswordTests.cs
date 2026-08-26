namespace PartyPlan.UnitTests;

using PartyPlan.Modules.Auth.Application;
using Shouldly;
using Xunit;

/// <summary>
/// Politique et hachage des mots de passe (RG-AUTH-01, RG-AUTH-02). Ces tests protègent
/// la porte d'entrée du produit : un défaut ici expose tous les comptes.
/// </summary>
public sealed class PasswordPolicyTests
{
    private readonly PasswordPolicy _politique = new();

    [Theory]
    [InlineData("Court1!")]
    [InlineData("")]
    [InlineData(null)]
    public void Un_mot_de_passe_de_moins_de_huit_caracteres_est_refuse(string? mdp)
    {
        var resultat = _politique.Validate(mdp);

        resultat.IsFailure.ShouldBeTrue();
        resultat.Error.ShouldBe(PasswordPolicy.TooShort);
    }

    [Theory]
    [InlineData("minuscule1!", "majuscule absente")]
    [InlineData("MAJUSCULE1!", "minuscule absente")]
    [InlineData("MajusculeSansChiffre!", "chiffre absent")]
    [InlineData("MajusculeChiffre1", "caractère spécial absent")]
    public void Un_mot_de_passe_incomplet_est_refuse(string mdp, string raison)
    {
        // Les quatre classes sont exigées ensemble : refuser l'une d'elles ne suffit
        // pas, il faut vérifier chacune séparément, sinon un défaut de la vérification
        // ne se voit que sur un cas particulier.
        var resultat = _politique.Validate(mdp);

        resultat.IsFailure.ShouldBeTrue(raison);
        resultat.Error.ShouldBe(PasswordPolicy.MissingComplexity);
    }

    [Fact]
    public void Un_mot_de_passe_de_huit_caracteres_complet_est_accepte()
    {
        _politique.Validate("Kx7!vwqm").IsSuccess.ShouldBeTrue();
    }

    [Fact]
    public void Une_phrase_de_passe_depassant_trente_caracteres_est_refusee()
    {
        // Conséquence assumée du plafond à 30 : une phrase de passe, pourtant la
        // défense la plus solide, ne passe plus. Le test existe pour que ce soit une
        // décision visible et non une découverte.
        _politique.Validate("Trombone-Nuage-Cerf-Volant-42x!")
            .Error.ShouldBe(PasswordPolicy.TooLong);
    }

    [Fact]
    public void Un_mot_de_passe_trop_long_est_refuse()
    {
        // Plafond nécessaire : Argon2id sur une entrée de plusieurs mégaoctets serait
        // un vecteur de déni de service.
        _politique.Validate(new string('a', PasswordPolicy.MaxLength + 1))
            .Error.ShouldBe(PasswordPolicy.TooLong);
    }

    [Fact]
    public void Un_mot_de_passe_inedit_et_complet_est_accepte()
    {
        _politique.Validate("Vahn7-Quorlim").IsSuccess.ShouldBeTrue();
    }

    [Theory]
    [InlineData("motdepasse123456")]
    [InlineData("password123456")]
    [InlineData("azertyuiop2026")]
    [InlineData("123456789012")]
    public void Un_mot_de_passe_compromis_est_refuse_malgre_sa_longueur(string mdp)
    {
        // Douze caractères ne suffisent pas : « password123456 » satisfait la longueur
        // et figure dans toutes les listes de divulgation.
        _politique.Validate(mdp).Error.ShouldBe(PasswordPolicy.Compromised);
    }

    [Fact]
    public void La_liste_des_mots_de_passe_compromis_est_chargee()
    {
        // Une ressource embarquée absente ferait passer la validation silencieusement.
        PasswordPolicy.CompromisedCount.ShouldBeGreaterThan(40_000);
    }

    [Fact]
    public void Aucune_liste_en_clair_n_est_embarquee()
    {
        // La ressource ne contient que des condensés tronqués : un mot de passe connu
        // n'y apparaît jamais littéralement.
        var assembly = typeof(PasswordPolicy).Assembly;
        var nom = assembly.GetManifestResourceNames()
            .Single(n => n.EndsWith("mots-de-passe-compromis.txt", StringComparison.Ordinal));

        using var flux = assembly.GetManifestResourceStream(nom)!;
        using var lecteur = new StreamReader(flux);
        var premiere = lecteur.ReadLine()!;

        premiere.Length.ShouldBe(PasswordPolicy.CondenseLength);
        premiere.ShouldAllBe(c => Uri.IsHexDigit(c));
    }
}

public sealed class PasswordHasherTests
{
    private readonly PasswordHasher _hacheur = new();

    [Fact]
    public void Une_empreinte_valide_le_mot_de_passe_d_origine()
    {
        var empreinte = _hacheur.Hash("Vahn7-Quorlim.Dessac");

        _hacheur.Verify("Vahn7-Quorlim.Dessac", empreinte).ShouldBeTrue();
    }

    [Fact]
    public void Un_mot_de_passe_different_est_rejete()
    {
        var empreinte = _hacheur.Hash("Vahn7-Quorlim.Dessac");

        _hacheur.Verify("Vahn7-Quorlim.Dessad", empreinte).ShouldBeFalse();
    }

    [Fact]
    public void Deux_empreintes_du_meme_mot_de_passe_diffèrent()
    {
        // Sel aléatoire : sans lui, deux comptes partageant un mot de passe seraient
        // identifiables dans une fuite de base.
        _hacheur.Hash("Vahn7-Quorlim.Dessac")
            .ShouldNotBe(_hacheur.Hash("Vahn7-Quorlim.Dessac"));
    }

    [Fact]
    public void L_empreinte_porte_ses_parametres()
    {
        // Indispensable pour relever le coût plus tard sans invalider l'existant.
        var empreinte = _hacheur.Hash("Vahn7-Quorlim.Dessac");

        empreinte.ShouldStartWith("argon2id$65536$3$2$");
        empreinte.Split('$').Length.ShouldBe(6);
    }

    [Fact]
    public void L_empreinte_ne_contient_pas_le_mot_de_passe()
    {
        _hacheur.Hash("Vahn7-Quorlim.Dessac").ShouldNotContain("Quorlim");
    }

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("pas-un-format")]
    [InlineData("argon2id$abc$3$2$c2VsdA==$aGFzaA==")]
    [InlineData("argon2id$65536$3$2$pas-du-base64$aGFzaA==")]
    public void Une_empreinte_malformee_ne_valide_jamais(string? empreinte)
    {
        // Une empreinte corrompue doit refuser, jamais lever : une exception non gérée
        // sur le chemin de connexion serait exploitable.
        _hacheur.Verify("Vahn7-Quorlim.Dessac", empreinte).ShouldBeFalse();
    }

    [Fact]
    public void Un_mot_de_passe_vide_ne_valide_jamais()
    {
        var empreinte = _hacheur.Hash("Vahn7-Quorlim.Dessac");

        _hacheur.Verify(string.Empty, empreinte).ShouldBeFalse();
    }

    [Fact]
    public void Une_empreinte_courante_n_a_pas_besoin_d_etre_rehachee()
    {
        _hacheur.NeedsRehash(_hacheur.Hash("Vahn7-Quorlim.Dessac")).ShouldBeFalse();
    }

    [Fact]
    public void Une_empreinte_a_cout_plus_faible_doit_etre_rehachee()
    {
        _hacheur.NeedsRehash("argon2id$4096$2$1$c2VsdA==$aGFzaA==").ShouldBeTrue();
    }
}
