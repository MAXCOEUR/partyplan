namespace PartyPlan.SharedKernel.Primitives;

/// <summary>
/// Résultat d'une opération sans valeur de retour. Les erreurs métier sont des valeurs,
/// pas des exceptions : une exception signale une anomalie, jamais un cas prévu.
/// </summary>
public readonly struct Result
{
    private Result(DomainError? error) => Error = error;

    public DomainError? Error { get; }

    public bool IsSuccess => Error is null;

    public bool IsFailure => Error is not null;

    public static Result Success() => new(null);

    public static Result Failure(DomainError error) => new(error);

    public static implicit operator Result(DomainError error) => Failure(error);
}

/// <summary>Résultat d'une opération porteuse d'une valeur.</summary>
public readonly struct Result<T>
{
    private readonly T? _value;

    private Result(T? value, DomainError? error)
    {
        _value = value;
        Error = error;
    }

    public DomainError? Error { get; }

    public bool IsSuccess => Error is null;

    public bool IsFailure => Error is not null;

    /// <summary>Valeur du résultat. L'accès en cas d'échec est une erreur de programmation.</summary>
    public T Value => IsSuccess
        ? _value!
        : throw new InvalidOperationException($"Résultat en échec ({Error!.Code}) : aucune valeur disponible.");

    public static Result<T> Success(T value) => new(value, null);

    public static Result<T> Failure(DomainError error) => new(default, error);

    public static implicit operator Result<T>(T value) => Success(value);

    public static implicit operator Result<T>(DomainError error) => Failure(error);
}
