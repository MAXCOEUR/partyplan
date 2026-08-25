# syntax=docker/dockerfile:1

# ---------- Étape de compilation ----------
#
# `--platform=$BUILDPLATFORM` : la compilation tourne sur l'architecture de la machine
# de construction, jamais sous émulation. Le résultat d'un `dotnet publish` portable est
# indépendant de l'architecture — les bibliothèques natives, SkiaSharp comprise, sont
# livrées pour toutes les cibles dans `runtimes/` et résolues au démarrage. Compiler
# sous QEMU multiplierait la durée par dix pour un résultat identique.
FROM --platform=$BUILDPLATFORM mcr.microsoft.com/dotnet/sdk:10.0-noble AS build
WORKDIR /src

# Les fichiers de configuration et les .csproj d'abord : la couche de restauration est
# réutilisée tant qu'aucune dépendance ne change, ce qui évite de retélécharger
# l'ensemble des paquets à chaque modification de code.
COPY Directory.Build.props Directory.Packages.props ./
COPY src/PartyPlan.SharedKernel/*.csproj ./src/PartyPlan.SharedKernel/
COPY src/PartyPlan.Infrastructure/*.csproj ./src/PartyPlan.Infrastructure/
COPY src/PartyPlan.Api/*.csproj ./src/PartyPlan.Api/
COPY src/PartyPlan.Modules.Auth/*.csproj ./src/PartyPlan.Modules.Auth/
COPY src/PartyPlan.Modules.Users/*.csproj ./src/PartyPlan.Modules.Users/
COPY src/PartyPlan.Modules.Events/*.csproj ./src/PartyPlan.Modules.Events/
COPY src/PartyPlan.Modules.Shopping/*.csproj ./src/PartyPlan.Modules.Shopping/
COPY src/PartyPlan.Modules.Expenses/*.csproj ./src/PartyPlan.Modules.Expenses/
COPY src/PartyPlan.Modules.Settlements/*.csproj ./src/PartyPlan.Modules.Settlements/
COPY src/PartyPlan.Modules.Tasks/*.csproj ./src/PartyPlan.Modules.Tasks/
COPY src/PartyPlan.Modules.Polls/*.csproj ./src/PartyPlan.Modules.Polls/
COPY src/PartyPlan.Modules.Messages/*.csproj ./src/PartyPlan.Modules.Messages/
COPY src/PartyPlan.Modules.Notifications/*.csproj ./src/PartyPlan.Modules.Notifications/
COPY src/PartyPlan.Modules.Administration/*.csproj ./src/PartyPlan.Modules.Administration/

# Le projet hôte seul : les tests et l'outil de démonstration n'ont pas à être
# restaurés pour produire l'image de production.
RUN dotnet restore src/PartyPlan.Api/PartyPlan.Api.csproj

COPY src/ ./src/

RUN dotnet publish src/PartyPlan.Api/PartyPlan.Api.csproj \
      -c Release \
      -o /app/publish \
      --no-restore \
      /p:UseAppHost=false

# ---------- Image d'exécution ----------
FROM mcr.microsoft.com/dotnet/aspnet:10.0-noble AS runtime
WORKDIR /app

# Deux paquets, deux raisons.
#
# curl est requis par le contrôle d'état ci-dessous : l'image aspnet ne le fournit pas.
#
# libfontconfig1 est exigé par SkiaSharp.NativeAssets.Linux. Sans lui, la première
# utilisation de SkiaSharp lève une DllNotFoundException sur « libfontconfig.so.1 » et
# tout envoi d'image échoue en 500 — alors que libSkiaSharp.so est bien dans l'image.
# Le défaut ne se voit ni à la construction, ni au démarrage, ni sur /health : seulement
# au premier envoi de photo. Le paquet reste nécessaire même si le code ne dessine aucun
# texte, la vérification de compatibilité de SkiaSharp s'exécutant au chargement du type.
RUN apt-get update \
 && apt-get install -y --no-install-recommends curl libfontconfig1 \
 && rm -rf /var/lib/apt/lists/*

# Exécution sans privilèges (utilisateur `app` fourni par l'image de base).
USER app

ENV ASPNETCORE_URLS=http://+:8080 \
    ASPNETCORE_ENVIRONMENT=Production \
    DOTNET_gcServer=1

COPY --from=build /app/publish ./
EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD ["/usr/bin/curl", "-fsS", "http://127.0.0.1:8080/health/live"]

ENTRYPOINT ["dotnet", "PartyPlan.Api.dll"]
