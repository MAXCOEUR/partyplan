namespace PartyPlan.UnitTests;

using PartyPlan.Infrastructure.Idempotency;
using Shouldly;
using Xunit;

/// <summary>
/// Empreinte d'une requête idempotente (§8.1).
/// <para>
/// Sans idempotence, un double appui sur « enregistrer la dépense » crée deux dépenses
/// et fausse tous les soldes de l'événement. Le réseau mobile rend ce double envoi
/// courant, non exceptionnel.
/// </para>
/// </summary>
public sealed class IdempotencyFingerprintTests
{
    [Fact]
    public void Deux_corps_identiques_donnent_la_meme_empreinte()
    {
        var premiere = IdempotencyFingerprint.Compute("""{"montant":3150}""");
        var seconde = IdempotencyFingerprint.Compute("""{"montant":3150}""");

        premiere.ShouldBe(seconde);
    }

    [Fact]
    public void Deux_corps_differents_donnent_des_empreintes_differentes()
    {
        // C'est ce qui distingue une réémission d'une seconde dépense légitime portant
        // par mégarde la même clé.
        IdempotencyFingerprint.Compute("""{"montant":3150}""")
            .ShouldNotBe(IdempotencyFingerprint.Compute("""{"montant":3151}"""));
    }

    [Fact]
    public void L_empreinte_ne_contient_pas_le_corps()
    {
        // La table d'idempotence n'a pas à conserver les montants en clair.
        IdempotencyFingerprint.Compute("""{"montant":3150,"libelle":"Bières"}""")
            .ShouldNotContain("Bières");
    }

    [Fact]
    public void Un_corps_vide_produit_une_empreinte_stable()
    {
        IdempotencyFingerprint.Compute(string.Empty)
            .ShouldBe(IdempotencyFingerprint.Compute(string.Empty));
    }

    [Fact]
    public void L_empreinte_tient_dans_la_colonne_prevue()
    {
        // La colonne est déclarée en 128 caractères.
        IdempotencyFingerprint.Compute("""{"x":1}""").Length.ShouldBeLessThanOrEqualTo(128);
    }
}

/// <summary>Validation de la clé fournie par le client.</summary>
public sealed class IdempotencyKeyValidationTests
{
    [Theory]
    [InlineData("0198f000-0000-7000-8000-000000000000", true)]
    [InlineData("une-cle-lisible-42", true)]
    [InlineData("", false)]
    [InlineData("   ", false)]
    [InlineData(null, false)]
    public void Une_cle_vide_est_refusee(string? cle, bool valide)
    {
        IdempotencyFingerprint.IsValidKey(cle).ShouldBe(valide);
    }

    [Fact]
    public void Une_cle_trop_longue_est_refusee()
    {
        // Plafond nécessaire : une clé de plusieurs mégaoctets serait un vecteur de
        // saturation de la table.
        IdempotencyFingerprint.IsValidKey(new string('a', 129)).ShouldBeFalse();
        IdempotencyFingerprint.IsValidKey(new string('a', 128)).ShouldBeTrue();
    }
}
