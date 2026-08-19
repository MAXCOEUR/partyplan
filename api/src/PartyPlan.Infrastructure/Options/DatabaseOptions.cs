namespace PartyPlan.Infrastructure.Options;

public sealed class DatabaseOptions
{
    public const string SectionName = "Database";

    /// <summary>
    /// Application des migrations au démarrage (§13.3). Activée par défaut : la base
    /// locale et la production suivent exactement le même chemin (NF-DEV-08).
    /// </summary>
    public bool MigrateOnStartup { get; set; } = true;

    /// <summary>Jeu de données de démonstration, réservé au développement (NF-DEV-07).</summary>
    public bool SeedDemoData { get; set; }
}
