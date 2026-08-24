namespace PartyPlan.IntegrationTests;

using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using PartyPlan.IntegrationTests.Infrastructure;
using PartyPlan.SharedKernel.Enums;
using Shouldly;
using Xunit;

/// <summary>
/// Parcours de compte et d'administration (V0.5), à travers l'API réelle.
/// <para>
/// Ces tests doublent la recette manuelle de <c>tools/recette/parcours-comptes.py</c>,
/// qui exige un serveur de courriel et une API démarrée. Ceux-ci tournent en intégration
/// continue, où ni l'un ni l'autre n'existe.
/// </para>
/// </summary>
[Collection(ApiTestSuite.Name)]
public sealed class CompteEtAdministrationTests(PartyPlanApiFixture fixture)
{
    private const string MotDePasseValide = "Trombone-Nuage-42x";

    [Theory]
    [InlineData("court", "password.too_short")]
    [InlineData("motdepasse123456", "password.compromised")]
    [InlineData("azertyuiop2026", "password.compromised")]
    public async Task Un_mot_de_passe_refuse_empeche_l_inscription(string motDePasse, string code)
    {
        using var client = fixture.CreateClient();

        var reponse = await client.PostAsJsonAsync("/v1/auth/register", new
        {
            email = Adresse(),
            password = motDePasse,
            displayName = "Test",
        });

        reponse.StatusCode.ShouldBe(HttpStatusCode.BadRequest);
        (await Code(reponse)).ShouldBe(code);
    }

    [Fact]
    public async Task Une_inscription_ouvre_une_session_et_le_profil_est_lisible()
    {
        using var client = fixture.CreateClient();
        var adresse = Adresse();

        var jetons = await Inscrire(client, adresse);
        jetons.ShouldNotBeNull();

        using var authentifie = fixture.CreateClient();
        authentifie.DefaultRequestHeaders.Authorization =
            new AuthenticationHeaderValue("Bearer", jetons!.Value.acces);

        var profil = await authentifie.GetFromJsonAsync<JsonDocument>("/v1/me");

        profil!.RootElement.GetProperty("email").GetString().ShouldBe(adresse);
        profil.RootElement.GetProperty("platformRole").GetString().ShouldBe("User");

        // L'adresse n'est pas vérifiée à l'inscription : elle l'est par le lien reçu.
        profil.RootElement.GetProperty("emailVerified").GetBoolean().ShouldBeFalse();

        // L'empreinte du mot de passe ne doit jamais franchir l'API (RG-AUTH-02).
        var brut = profil.RootElement.GetRawText();
        brut.ShouldNotContain("argon2");
        brut.ShouldNotContain("passwordHash");
    }

    [Fact]
    public async Task Une_adresse_deja_utilisee_est_refusee()
    {
        using var client = fixture.CreateClient();
        var adresse = Adresse();

        await Inscrire(client, adresse);

        var reponse = await client.PostAsJsonAsync("/v1/auth/register", new
        {
            email = adresse,
            password = MotDePasseValide,
            displayName = "Doublon",
        });

        reponse.StatusCode.ShouldBe(HttpStatusCode.Conflict);
        (await Code(reponse)).ShouldBe("auth.email_already_used");
    }

    [Fact]
    public async Task Un_mot_de_passe_errone_et_une_adresse_inconnue_donnent_la_meme_erreur()
    {
        using var client = fixture.CreateClient();
        var adresse = Adresse();
        await Inscrire(client, adresse);

        var mauvaisMotDePasse = await client.PostAsJsonAsync("/v1/auth/login", new
        {
            email = adresse,
            password = "Cerf-Volant-Ocre-91",
        });

        var adresseInconnue = await client.PostAsJsonAsync("/v1/auth/login", new
        {
            email = Adresse(),
            password = MotDePasseValide,
        });

        // Distinguer les deux cas fournirait un oracle d'existence de comptes.
        mauvaisMotDePasse.StatusCode.ShouldBe(adresseInconnue.StatusCode);
        (await Code(mauvaisMotDePasse)).ShouldBe(await Code(adresseInconnue));
    }

    [Fact]
    public async Task La_demande_de_reinitialisation_repond_pareil_que_l_adresse_existe_ou_non()
    {
        using var client = fixture.CreateClient();
        var adresse = Adresse();
        await Inscrire(client, adresse);

        var connue = await client.PostAsJsonAsync("/v1/auth/password/forgot", new { email = adresse });
        var inconnue = await client.PostAsJsonAsync("/v1/auth/password/forgot", new { email = Adresse() });

        // RG-AUTH-04
        connue.StatusCode.ShouldBe(HttpStatusCode.Accepted);
        inconnue.StatusCode.ShouldBe(HttpStatusCode.Accepted);
    }

    [Fact]
    public async Task Le_jeton_de_rafraichissement_tourne_et_l_ancien_est_refuse()
    {
        using var client = fixture.CreateClient();
        var jetons = await Inscrire(client, Adresse());

        var premier = await client.PostAsJsonAsync("/v1/auth/refresh", new
        {
            refreshToken = jetons!.Value.rafraichissement,
        });

        premier.StatusCode.ShouldBe(HttpStatusCode.OK);

        var nouveau = (await premier.Content.ReadFromJsonAsync<JsonDocument>())!
            .RootElement.GetProperty("refreshToken").GetString();

        nouveau.ShouldNotBe(jetons.Value.rafraichissement);

        // Rejouer l'ancien jeton doit échouer : c'est ce qui borne l'exploitation d'un vol.
        var rejeu = await client.PostAsJsonAsync("/v1/auth/refresh", new
        {
            refreshToken = jetons.Value.rafraichissement,
        });

        rejeu.StatusCode.ShouldBe(HttpStatusCode.BadRequest);
    }

    [Fact]
    public async Task Un_compte_suspendu_ne_peut_plus_se_connecter()
    {
        using var client = fixture.CreateClient();
        var adresse = Adresse();
        var jetons = await Inscrire(client, adresse);

        var identifiant = await IdentifiantDe(adresse);
        await SuspendreAsync(identifiant, "Test d'intégration");

        var reponse = await client.PostAsJsonAsync("/v1/auth/login", new
        {
            email = adresse,
            password = MotDePasseValide,
        });

        // RG-ADM-07
        reponse.StatusCode.ShouldBe(HttpStatusCode.Forbidden);
        (await Code(reponse)).ShouldBe("auth.account_suspended");

        // Le rafraîchissement est également coupé : sans cela, une session ouverte
        // survivrait à la suspension pendant quatre-vingt-dix jours.
        var rafraichissement = await client.PostAsJsonAsync("/v1/auth/refresh", new
        {
            refreshToken = jetons!.Value.rafraichissement,
        });

        rafraichissement.StatusCode.ShouldBe(HttpStatusCode.BadRequest);
    }

    [Fact]
    public async Task Un_utilisateur_ordinaire_n_accede_pas_a_l_administration()
    {
        using var client = fixture.CreateClient();
        var jetons = await Inscrire(client, Adresse());

        using var authentifie = fixture.CreateClient();
        authentifie.DefaultRequestHeaders.Authorization =
            new AuthenticationHeaderValue("Bearer", jetons!.Value.acces);

        (await authentifie.GetAsync(new Uri("/v1/admin/users", UriKind.Relative)))
            .StatusCode.ShouldBe(HttpStatusCode.Forbidden);

        (await authentifie.GetAsync(new Uri("/v1/admin/audit", UriKind.Relative)))
            .StatusCode.ShouldBe(HttpStatusCode.Forbidden);
    }

    [Fact]
    public async Task Un_appelant_anonyme_n_accede_pas_a_l_administration()
    {
        using var client = fixture.CreateClient();

        (await client.GetAsync(new Uri("/v1/admin/users", UriKind.Relative)))
            .StatusCode.ShouldBe(HttpStatusCode.Unauthorized);
    }

    [Fact]
    public async Task Un_role_plateforme_accede_sans_second_facteur()
    {
        // ADR 0007 : la double authentification n'est plus exigée des rôles plateforme.
        // Elle rendait l'administration inatteignable — le compte amorcé n'en a pas,
        // l'activer demandait d'y accéder, et le back-office répondait « accès refusé »
        // à son seul administrateur.
        //
        // Le mot de passe devient donc l'unique protection d'un compte capable de
        // réinitialiser et de supprimer tous les autres. Ce test fixe ce choix pour
        // qu'un retour en arrière soit délibéré et non accidentel.
        using var client = fixture.CreateClient();
        var adresse = Adresse();
        await Inscrire(client, adresse);
        var identifiant = await IdentifiantDe(adresse);

        await PromouvoirAsync(identifiant, PlatformRole.PlatformAdmin);

        var session = await client.PostAsJsonAsync("/v1/auth/login", new
        {
            email = adresse,
            password = MotDePasseValide,
        });

        var acces = (await session.Content.ReadFromJsonAsync<JsonDocument>())!
            .RootElement.GetProperty("accessToken").GetString();

        using var admin = fixture.CreateClient();
        admin.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", acces);

        (await admin.GetAsync(new Uri("/v1/admin/users", UriKind.Relative)))
            .StatusCode.ShouldBe(HttpStatusCode.OK);
    }

    [Fact]
    public async Task Un_support_consulte_mais_ne_supprime_pas()
    {
        using var client = fixture.CreateClient();
        var adresse = Adresse();
        var jetons = await Inscrire(client, adresse);
        var identifiant = await IdentifiantDe(adresse);

        await PromouvoirAsync(identifiant, PlatformRole.Support);

        // Le rôle est porté par le jeton : une nouvelle session est nécessaire.
        var acces = await ConnecterAsync(client, adresse);

        using var support = fixture.CreateClient();
        support.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", acces);

        (await support.GetAsync(new Uri("/v1/admin/users?pageSize=1", UriKind.Relative)))
            .StatusCode.ShouldBe(HttpStatusCode.OK);

        // RG-ADM-05 : suppression et suspension réservées à PlatformAdmin.
        (await support.DeleteAsync(new Uri($"/v1/admin/users/{identifiant}", UriKind.Relative)))
            .StatusCode.ShouldBe(HttpStatusCode.Forbidden);

        (await support.PostAsJsonAsync(
                $"/v1/admin/users/{identifiant}/suspend",
                new { reason = "test" }))
            .StatusCode.ShouldBe(HttpStatusCode.Forbidden);
    }

    [Fact]
    public async Task La_suppression_libere_l_adresse_et_anonymise_le_compte()
    {
        using var client = fixture.CreateClient();
        var adresse = Adresse();
        var jetons = await Inscrire(client, adresse);

        using var authentifie = fixture.CreateClient();
        authentifie.DefaultRequestHeaders.Authorization =
            new AuthenticationHeaderValue("Bearer", jetons!.Value.acces);

        using var requete = new HttpRequestMessage(
            HttpMethod.Delete,
            new Uri("/v1/me", UriKind.Relative))
        {
            Content = JsonContent.Create(new { emailConfirmation = "mauvaise@adresse.fr" }),
        };

        var refus = await authentifie.SendAsync(requete);
        refus.StatusCode.ShouldBe(HttpStatusCode.BadRequest);

        using var confirmee = new HttpRequestMessage(
            HttpMethod.Delete,
            new Uri("/v1/me", UriKind.Relative))
        {
            Content = JsonContent.Create(new { emailConfirmation = adresse }),
        };

        (await authentifie.SendAsync(confirmee)).StatusCode.ShouldBe(HttpStatusCode.NoContent);

        // RG-RGPD-01 : la ligne subsiste, anonymisée, afin de ne pas détruire la
        // comptabilité d'événements auxquels d'autres personnes participent.
        await fixture.WithDatabaseAsync(async db =>
        {
            var compte = await db.Users
                .IgnoreQueryFilters()
                .SingleAsync(u => u.Email == null && u.DisplayName == "Ancien participant"
                                  && u.DeletedAt != null);

            compte.PasswordHash.ShouldBeNull();
            compte.PlatformRole.ShouldBe(PlatformRole.User);
        });

        // RG-USR-06 : l'adresse est libérée.
        var reinscription = await client.PostAsJsonAsync("/v1/auth/register", new
        {
            email = adresse,
            password = MotDePasseValide,
            displayName = "Réinscription",
        });

        reinscription.StatusCode.ShouldBe(HttpStatusCode.OK);
    }

    [Fact]
    public async Task Les_indicateurs_d_instance_comptent_les_evenements()
    {
        using var client = fixture.CreateClient();
        var adresse = Adresse();
        var jetons = await Inscrire(client, adresse);
        var identifiant = await IdentifiantDe(adresse);

        // Un événement et un invité sans compte, pour que les décomptes soient non nuls.
        using var organisateur = fixture.CreateClient();
        organisateur.DefaultRequestHeaders.Authorization =
            new AuthenticationHeaderValue("Bearer", jetons!.Value.acces);

        var creation = await EvenementsTests.CreerBrutAsync(organisateur, new
        {
            name = "Pour les indicateurs",
            startsAt = DateTimeOffset.UtcNow.AddDays(5),
        });

        creation.StatusCode.ShouldBe(HttpStatusCode.OK);

        await PromouvoirAsync(identifiant, PlatformRole.PlatformAdmin);
        var acces = await ConnecterAsync(client, adresse);

        using var admin = fixture.CreateClient();
        admin.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", acces);

        var indicateurs = await admin.GetFromJsonAsync<JsonDocument>("/v1/admin/metrics");

        indicateurs!.RootElement.GetProperty("totalUsers").GetInt32().ShouldBeGreaterThan(0);
        indicateurs.RootElement.GetProperty("totalEvents").GetInt32().ShouldBeGreaterThan(0);
        indicateurs.RootElement.GetProperty("activeEvents").GetInt32().ShouldBeGreaterThan(0);

        // RG-ADM-01 : des nombres, jamais de contenu. Aucun nom d'événement ne doit
        // apparaître dans les indicateurs.
        indicateurs.RootElement.GetRawText().ShouldNotContain("Pour les indicateurs");
    }

    [Fact]
    public async Task L_administrateur_exporte_les_donnees_d_un_compte_et_supprime_une_photo()
    {
        using var client = fixture.CreateClient();
        var adresseAdmin = Adresse();
        await Inscrire(client, adresseAdmin);
        var identifiantAdmin = await IdentifiantDe(adresseAdmin);

        var cible = Adresse();
        await Inscrire(client, cible);
        var identifiantCible = await IdentifiantDe(cible);

        await PromouvoirAsync(identifiantAdmin, PlatformRole.Support);
        var acces = await ConnecterAsync(client, adresseAdmin);

        using var support = fixture.CreateClient();
        support.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", acces);

        var export = await support.GetAsync(
            new Uri($"/v1/admin/users/{identifiantCible}/export", UriKind.Relative));

        export.StatusCode.ShouldBe(HttpStatusCode.OK);

        var contenu = await export.Content.ReadAsStringAsync();
        contenu.ShouldContain(cible);

        // Même contenu que l'export en libre-service : l'administrateur n'a pas accès à
        // davantage, en particulier pas à l'empreinte du mot de passe.
        contenu.ShouldNotContain("argon2");

        // La suppression de photo aboutit même en l'absence de photo : l'action est
        // idempotente, un signalement peut arriver après un retrait volontaire.
        (await support.DeleteAsync(
                new Uri($"/v1/admin/users/{identifiantCible}/avatar", UriKind.Relative)))
            .StatusCode.ShouldBe(HttpStatusCode.NoContent);

        var journal = await support.GetFromJsonAsync<JsonDocument>("/v1/admin/audit?pageSize=20");
        var actions = journal!.RootElement.EnumerateArray()
            .Select(e => e.GetProperty("action").GetString())
            .ToList();

        // Un accès à des données personnelles est journalisé, même à la demande de la
        // personne concernée (RG-ADM-06).
        actions.ShouldContain("user.data_exported");
        actions.ShouldContain("user.avatar_removed");
    }

    private static string Adresse() => $"test-{Guid.CreateVersion7():N}@partyplan.test";

    private static async Task<string?> Code(HttpResponseMessage reponse)
    {
        var corps = await reponse.Content.ReadFromJsonAsync<JsonDocument>();

        return corps!.RootElement.TryGetProperty("code", out var code) ? code.GetString() : null;
    }

    private static async Task<(string acces, string rafraichissement)?> Inscrire(
        HttpClient client,
        string adresse)
    {
        var reponse = await client.PostAsJsonAsync("/v1/auth/register", new
        {
            email = adresse,
            password = MotDePasseValide,
            displayName = "Test",
        });

        if (reponse.StatusCode != HttpStatusCode.OK)
        {
            return null;
        }

        var corps = await reponse.Content.ReadFromJsonAsync<JsonDocument>();

        return (
            corps!.RootElement.GetProperty("accessToken").GetString()!,
            corps.RootElement.GetProperty("refreshToken").GetString()!);
    }

    private async Task<Guid> IdentifiantDe(string adresse)
    {
        var identifiant = Guid.Empty;

        await fixture.WithDatabaseAsync(async db =>
        {
            identifiant = await db.Users
                .Where(u => u.Email == adresse)
                .Select(u => u.Id)
                .SingleAsync();
        });

        return identifiant;
    }

    /// <summary>
    /// Suspend directement en base. Passer par l'API exigerait une session
    /// d'administration, dont le mot de passe amorcé est propre à la configuration de
    /// test : le raccourci porte sur la mise en place, jamais sur ce qui est vérifié.
    /// </summary>
    private Task SuspendreAsync(Guid identifiant, string motif) =>
        fixture.WithDatabaseAsync(async db =>
        {
            var compte = await db.Users.SingleAsync(u => u.Id == identifiant);
            compte.SuspendedAt = DateTimeOffset.UtcNow;
            compte.SuspensionReason = motif;

            var sessions = await db.Sessions
                .Where(s => s.UserId == identifiant && s.RevokedAt == null)
                .ToListAsync();

            foreach (var session in sessions)
            {
                session.RevokedAt = DateTimeOffset.UtcNow;
            }

            await db.SaveChangesAsync();
        });

    /// <summary>Promeut directement en base.</summary>
    private async Task PromouvoirAsync(Guid identifiant, PlatformRole role) =>
        await fixture.WithDatabaseAsync(async db =>
        {
            var compte = await db.Users.SingleAsync(u => u.Id == identifiant);
            compte.PlatformRole = role;
            await db.SaveChangesAsync();
        });

    /// <summary>
    /// Ouvre une session et renvoie le jeton d'accès.
    /// <para>
    /// En une seule étape : la double authentification est retirée du produit — ADR 0007 —
    /// y compris pour les rôles plateforme.
    /// </para>
    /// </summary>
    private static async Task<string> ConnecterAsync(HttpClient client, string adresse)
    {
        var connexion = await client.PostAsJsonAsync("/v1/auth/login", new
        {
            email = adresse,
            password = MotDePasseValide,
        });

        connexion.StatusCode.ShouldBe(HttpStatusCode.OK);

        var corps = (await connexion.Content.ReadFromJsonAsync<JsonDocument>())!.RootElement;

        return corps.GetProperty("accessToken").GetString()!;
    }
}

/// <summary>
/// Comptes dépourvus de mot de passe (RG-AUTH-08).
/// <para>
/// Un compte créé par connexion tierce n'a pas d'empreinte. Le parcours de
/// réinitialisation est son seul moyen d'en définir une : le lui refuser l'enfermerait
/// dans une dépendance au fournisseur tiers.
/// </para>
/// </summary>
[Collection(ApiTestSuite.Name)]
public sealed class CompteSansMotDePasseTests(PartyPlanApiFixture fixture)
{
    [Fact]
    public async Task Un_compte_sans_mot_de_passe_peut_en_definir_un_par_reinitialisation()
    {
        var adresse = $"tiers-{Guid.CreateVersion7():N}@partyplan.test";

        // Compte créé sans empreinte, comme le ferait une connexion tierce.
        await fixture.WithDatabaseAsync(async db =>
        {
            db.Users.Add(new PartyPlan.Modules.Users.Domain.User
            {
                Id = Guid.CreateVersion7(),
                Email = adresse,
                DisplayName = "Compte tiers",
                EmailVerifiedAt = DateTimeOffset.UtcNow,
                GoogleSubject = $"google-{Guid.CreateVersion7():N}",
            });

            await db.SaveChangesAsync();
        });

        using var client = fixture.CreateClient();

        var demande = await client.PostAsJsonAsync("/v1/auth/password/forgot", new { email = adresse });

        // La réponse est de toute façon invariable (RG-AUTH-04) ; ce qui compte est
        // qu'un jeton ait bien été créé.
        demande.StatusCode.ShouldBe(HttpStatusCode.Accepted);

        var jetonCree = false;

        await fixture.WithDatabaseAsync(async db =>
        {
            jetonCree = await db.PasswordResetTokens
                .AnyAsync(t => db.Users.Any(u => u.Id == t.UserId && u.Email == adresse));
        });

        jetonCree.ShouldBeTrue();
    }

    [Fact]
    public async Task Un_compte_sans_mot_de_passe_ne_se_connecte_pas_par_mot_de_passe()
    {
        var adresse = $"tiers2-{Guid.CreateVersion7():N}@partyplan.test";

        await fixture.WithDatabaseAsync(async db =>
        {
            db.Users.Add(new PartyPlan.Modules.Users.Domain.User
            {
                Id = Guid.CreateVersion7(),
                Email = adresse,
                DisplayName = "Compte tiers",
            });

            await db.SaveChangesAsync();
        });

        using var client = fixture.CreateClient();

        var connexion = await client.PostAsJsonAsync("/v1/auth/login", new
        {
            email = adresse,
            password = "Trombone-Nuage-42x",
        });

        // Une empreinte nulle ne doit jamais valider, quel que soit le mot de passe
        // présenté.
        connexion.StatusCode.ShouldBe(HttpStatusCode.BadRequest);
    }
}

/// <summary>
/// Connexions tierces sans clé configurée (NF-DEV-05, EF-AUTH-06, EF-AUTH-08).
/// <para>
/// Le développement doit se faire sans compte Google. L'endpoint doit donc refuser
/// proprement, et surtout ne jamais laisser passer un jeton non vérifié.
/// </para>
/// </summary>
[Collection(ApiTestSuite.Name)]
public sealed class ConnexionsTiercesTests(PartyPlanApiFixture fixture)
{
    [Fact]
    public async Task Sans_cle_configuree_la_connexion_google_refuse_proprement()
    {
        using var client = fixture.CreateClient();

        var reponse = await client.PostAsJsonAsync("/v1/auth/google", new
        {
            idToken = "un.jeton.quelconque",
        });

        // Un jeton non vérifié ne doit jamais ouvrir de session, même en développement.
        reponse.StatusCode.ShouldBe(HttpStatusCode.UnprocessableEntity);

        var corps = await reponse.Content.ReadFromJsonAsync<JsonDocument>();
        corps!.RootElement.GetProperty("code").GetString().ShouldBe("external.not_configured");
    }

    [Fact]
    public async Task L_inscription_et_la_connexion_par_mot_de_passe_fonctionnent_sans_cle()
    {
        // NF-DEV-05 : l'absence de clé tierce n'empêche rien.
        using var client = fixture.CreateClient();
        var adresse = $"sans-google-{Guid.CreateVersion7():N}@partyplan.test";

        var inscription = await client.PostAsJsonAsync("/v1/auth/register", new
        {
            email = adresse,
            password = "Trombone-Nuage-42x",
            displayName = "Sans Google",
        });

        inscription.StatusCode.ShouldBe(HttpStatusCode.OK);

        var connexion = await client.PostAsJsonAsync("/v1/auth/login", new
        {
            email = adresse,
            password = "Trombone-Nuage-42x",
        });

        connexion.StatusCode.ShouldBe(HttpStatusCode.OK);
    }

    [Fact]
    public async Task Detacher_le_dernier_moyen_de_connexion_est_refuse()
    {
        using var client = fixture.CreateClient();
        var adresse = $"lien-{Guid.CreateVersion7():N}@partyplan.test";

        var inscription = await client.PostAsJsonAsync("/v1/auth/register", new
        {
            email = adresse,
            password = "Trombone-Nuage-42x",
            displayName = "Rattaché",
        });

        var acces = (await inscription.Content.ReadFromJsonAsync<JsonDocument>())!
            .RootElement.GetProperty("accessToken").GetString();

        using var authentifie = fixture.CreateClient();
        authentifie.DefaultRequestHeaders.Authorization =
            new AuthenticationHeaderValue("Bearer", acces);

        // Aucun fournisseur rattaché : le détachement n'a pas d'objet.
        var inexistant = await authentifie.DeleteAsync(
            new Uri("/v1/auth/providers/google", UriKind.Relative));

        inexistant.StatusCode.ShouldBe(HttpStatusCode.BadRequest);

        // Compte sans mot de passe mais avec un fournisseur : le détacher enfermerait la
        // personne dehors, sans recours possible.
        var identifiant = Guid.Empty;

        await fixture.WithDatabaseAsync(async db =>
        {
            var compte = await db.Users.SingleAsync(u => u.Email == adresse);
            compte.PasswordHash = null;
            compte.GoogleSubject = $"google-{Guid.CreateVersion7():N}";
            identifiant = compte.Id;
            await db.SaveChangesAsync();
        });

        var refus = await authentifie.DeleteAsync(
            new Uri("/v1/auth/providers/google", UriKind.Relative));

        refus.StatusCode.ShouldBe(HttpStatusCode.UnprocessableEntity);

        var corps = await refus.Content.ReadFromJsonAsync<JsonDocument>();
        corps!.RootElement.GetProperty("code").GetString().ShouldBe("external.would_lock_out");

        identifiant.ShouldNotBe(Guid.Empty);
    }

    [Fact]
    public async Task La_liste_des_moyens_de_connexion_dit_ce_qui_est_disponible()
    {
        // L'écran de rattachement a besoin de deux informations distinctes : le service
        // est-il utilisable sur cette instance, et est-il déjà rattaché à ce compte.
        using var client = fixture.CreateClient();
        var adresse = $"moyens-{Guid.CreateVersion7():N}@partyplan.test";

        var inscription = await client.PostAsJsonAsync("/v1/auth/register", new
        {
            email = adresse,
            password = "Trombone-Nuage-42x",
            displayName = "Moyens",
        });

        var acces = (await inscription.Content.ReadFromJsonAsync<JsonDocument>())!
            .RootElement.GetProperty("accessToken").GetString();

        using var authentifie = fixture.CreateClient();
        authentifie.DefaultRequestHeaders.Authorization =
            new AuthenticationHeaderValue("Bearer", acces);

        var reponse = await authentifie.GetAsync(
            new Uri("/v1/auth/providers", UriKind.Relative));

        reponse.StatusCode.ShouldBe(HttpStatusCode.OK);

        var corps = await reponse.Content.ReadFromJsonAsync<JsonDocument>();
        var racine = corps!.RootElement;

        // Le mot de passe est un moyen de connexion comme un autre : sans lui dans la
        // liste, l'écran ne peut pas expliquer pourquoi un détachement est refusé.
        racine.GetProperty("hasPassword").GetBoolean().ShouldBeTrue();

        var fournisseurs = racine.GetProperty("providers").EnumerateArray().ToList();
        fournisseurs.Count.ShouldBe(2);

        var google = fournisseurs.Single(f => f.GetProperty("provider").GetString() == "google");

        // Aucune clé en test : le service est annoncé indisponible, et l'écran masque le
        // bouton plutôt que d'offrir une action qui échouera (NF-DEV-05).
        google.GetProperty("configured").GetBoolean().ShouldBeFalse();
        google.GetProperty("linked").GetBoolean().ShouldBeFalse();

        // Le sujet du fournisseur n'a rien à faire dans une réponse d'API.
        google.TryGetProperty("subject", out _).ShouldBeFalse();
    }

    [Fact]
    public async Task Un_fournisseur_rattache_est_signale_comme_tel()
    {
        using var client = fixture.CreateClient();
        var adresse = $"rattache-{Guid.CreateVersion7():N}@partyplan.test";

        var inscription = await client.PostAsJsonAsync("/v1/auth/register", new
        {
            email = adresse,
            password = "Trombone-Nuage-42x",
            displayName = "Rattaché",
        });

        var acces = (await inscription.Content.ReadFromJsonAsync<JsonDocument>())!
            .RootElement.GetProperty("accessToken").GetString();

        await fixture.WithDatabaseAsync(async db =>
        {
            var compte = await db.Users.SingleAsync(u => u.Email == adresse);
            compte.GoogleSubject = $"google-{Guid.CreateVersion7():N}";
            await db.SaveChangesAsync();
        });

        using var authentifie = fixture.CreateClient();
        authentifie.DefaultRequestHeaders.Authorization =
            new AuthenticationHeaderValue("Bearer", acces);

        var reponse = await authentifie.GetAsync(
            new Uri("/v1/auth/providers", UriKind.Relative));

        var corps = await reponse.Content.ReadFromJsonAsync<JsonDocument>();

        var google = corps!.RootElement.GetProperty("providers").EnumerateArray()
            .Single(f => f.GetProperty("provider").GetString() == "google");

        google.GetProperty("linked").GetBoolean().ShouldBeTrue();

        // Rattaché mais non configuré : l'écran doit pouvoir proposer le détachement
        // sans proposer le rattachement.
        google.GetProperty("configured").GetBoolean().ShouldBeFalse();
    }

    [Fact]
    public async Task La_liste_des_moyens_de_connexion_exige_une_session()
    {
        using var client = fixture.CreateClient();

        var reponse = await client.GetAsync(new Uri("/v1/auth/providers", UriKind.Relative));

        reponse.StatusCode.ShouldBe(HttpStatusCode.Unauthorized);
    }
}
