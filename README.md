# Pipeline DevSecOps — OWASP Juice Shop (Jenkins + GitHub + ngrok)

Ce dépôt contient l'infrastructure et le pipeline CI/CD utilisés pour automatiser l'analyse de sécurité (SAST + SCA) de l'application OWASP Juice Shop à chaque modification poussée sur GitHub.

## 1. Architecture générale

```
 Développeur
     │  git push
     ▼
 GitHub (juice_shop_scan_Jenkins) ──── Webhook (via ngrok) ────▶ Jenkins (Docker)
                                                                     │
                                                                     ├─ 1. Checkout du code
                                                                     ├─ 2. SAST — Semgrep (conteneur éphémère)
                                                                     ├─ 3. SCA — OWASP Dependency-Check (plugin Jenkins)
                                                                     └─ 4. Notification par e-mail (Gmail SMTP)
```

Jenkins tourne entièrement dans un conteneur Docker (isolation des dépendances), et dispose lui-même d'un accès au démon Docker de la machine hôte (via le socket monté) pour pouvoir lancer d'autres conteneurs (Semgrep) pendant les builds.

## 2. Contenu du dépôt

| Fichier / Dossier | Rôle |
|---|---|
| `juice-shop/` | Code source de l'application cible (OWASP Juice Shop), analysée par le pipeline |
| `Dockerfile` | Construit l'image Jenkins personnalisée (outils + plugins nécessaires) |
| `docker-compose-infra.yml` | Orchestre le conteneur Jenkins (build de l'image, volumes, ports) |
| `Jenkinsfile` | Définit le pipeline CI/CD (SAST, SCA, notification) |
| `Rapport_Automatisation_Jenkins_GitHub.pdf` | Rapport détaillant la mise en place et la configuration de l'infrastructure |
| `README.md` | Ce fichier |

## 3. Prérequis

- Docker Engine + Docker Compose installés sur la machine hôte
- Un compte GitHub avec un token d'accès personnel (pour le checkout et le webhook)
- Un compte Gmail avec un **mot de passe d'application** (pour l'envoi des rapports par e-mail)
- Une clé API NVD gratuite (recommandée pour accélérer le scan Dependency-Check) : https://nvd.nist.gov/developers/request-an-api-key
- ngrok installé (ou tout autre tunnel HTTPS) pour exposer Jenkins à GitHub en local

⚠️ **Important — nommage du dossier** : le `Jenkinsfile` référence explicitement le volume Docker `devops-infra-jenkins_jenkins-data` dans sa stage SAST. Ce nom est généré automatiquement par Docker Compose à partir du **nom du dossier contenant `docker-compose-infra.yml`**, préfixé au nom du volume déclaré (`jenkins-data`). Pour que cette référence reste valide telle quelle, le dossier du projet doit donc s'appeler exactement `devops-infra-jenkins` — sinon, adaptez le nom du volume dans le `Jenkinsfile` (stage 2, option `-v`), ou lancez Compose avec `-p devops-infra-jenkins` pour forcer le nom de projet.

## 4. Mise en place de l'infrastructure

### 4.1 Construire et démarrer Jenkins

```bash
git clone https://github.com/Pape-Ndiaga-diouf/juice_shop_scan_Jenkins.git devops-infra-jenkins
cd devops-infra-jenkins

docker compose -f docker-compose-infra.yml up -d --build
```

Cette commande :
1. Construit l'image Jenkins à partir du `Dockerfile` (installation de Docker CLI, Docker Compose, Python3, plugins Jenkins de base) ;
2. Démarre le conteneur `jenkins-Container`, expose les ports `8080` (interface web) et `50000` (agents Jenkins) ;
3. Monte le volume `jenkins-data` (persistance de la configuration Jenkins) et le socket Docker de l'hôte (`/var/run/docker.sock`), pour permettre à Jenkins de lancer des conteneurs (Semgrep) pendant les builds.

### 4.2 Récupérer le mot de passe administrateur initial

```bash
docker exec -it jenkins-Container cat /var/jenkins_home/secrets/initialAdminPassword
```

Puis ouvrez `http://localhost:8080` et collez ce mot de passe pour terminer l'installation.

### 4.3 Arrêter / relancer l'infrastructure

```bash
# Arrêter (sans supprimer les données Jenkins)
docker compose -f docker-compose-infra.yml down

# Relancer après une modification du Dockerfile
docker compose -f docker-compose-infra.yml up -d --build
```

## 5. Configuration Jenkins (après le premier démarrage)

Le `Dockerfile`contient les plugins de base nécessaires au pipeline (`workflow-aggregator`, `docker-workflow`, `git`, `credentials-binding`, `Dependency-Check Plugin`, `emailext`). Les plugins suivants doivent être ajoutés **manuellement** depuis l'interface Jenkins (*Manage Jenkins → Plugins*), car ils ne sont pas déclarés dans le `Dockerfile` :

### 5.1 Outil OWASP Dependency-Check
**Attention à un point important** : le plugin Dependency-Check permet d'utiliser dependencyCheck et dependencyCheckPublisher, mais l'installation *DP-check* doit toujours être correctement configurée.

*Manage Jenkins → Tools → Dependency-Check installations* :
- Nom : `DP-check`
- Install automatically ✅, installer "Install from github.com", version `dependency-check 13.0.0`

### 5.2 Clé API NVD (recommandé)

*Manage Jenkins → Credentials* → ajouter un credential de type **Secret text** contenant votre clé API NVD, puis référencez son ID dans le `Jenkinsfile` via `nvdCredentialsId`.

### 5.3 Identifiants Gmail (SMTP)

*Manage Jenkins → System → Extended E-mail Notification* :
- Serveur SMTP : `smtp.gmail.com`, port `587`, "Use TLS"
- Utilisateur : votre adresse Gmail
- Mot de passe : un **mot de passe d'application** Google (pas votre mot de passe habituel)

### 5.4 Identifiants GitHub

*Manage Jenkins → Credentials* → ajouter un token d'accès personnel GitHub, utilisé par Jenkins pour cloner le dépôt (`checkout`).

### 5.5 Webhook GitHub via ngrok

1. Démarrer un tunnel : `ngrok http 8080`
2. Copier l'URL HTTPS générée (ex. `https://xxxx.ngrok-free.app`)
3. Dans GitHub → *Settings → Webhooks → Add webhook* : coller `https://xxxx.ngrok-free.app/github-webhook/`, type de contenu `application/json`, événement `push`

Chaque `git push` déclenche alors automatiquement un build Jenkins.

## 6. Lancer et consulter une analyse

- **Déclenchement** : automatique à chaque push (webhook), ou manuellement via *Lancer un build* dans Jenkins.
- **Suivi en direct** : *Jenkins → scan-juice-chop → Console Output* du build en cours.
- **Rapports générés** (onglet *Last Successful Artifacts* du job) :
  - `semgrep-report.json` — résultats bruts SAST
  - `dependency-check-report.html` / `.json` / `.xml` / `.sarif` — résultats SCA sous plusieurs formats
  - Graphique **Dependency-Check Trend** — évolution du nombre de vulnérabilités par sévérité au fil des builds
- **Notification** : un e-mail récapitulatif (SAST + SCA) est envoyé automatiquement à la fin de chaque build, avec les rapports en pièce jointe.

## 7. Détail des fichiers clés

### `Dockerfile`
Part de l'image officielle `jenkins/jenkins:lts` et ajoute :
- les paquets système nécessaires (`curl`, `python3`, `ca-certificates`, etc.) ;
- le client Docker et Docker Compose, pour que Jenkins puisse piloter des conteneurs depuis les builds (ex. lancer `semgrep/semgrep`) ;
- les plugins Jenkins de base via `jenkins-plugin-cli` (Pipeline, Git, Docker Workflow, Credentials Binding).

### `docker-compose-infra.yml`
Construit l'image ci-dessus et démarre le conteneur `jenkins-Container` avec :
- les ports `8080` (UI) et `50000` (agents) exposés ;
- un volume nommé `jenkins-data` pour la persistance de `$JENKINS_HOME` ;
- le socket Docker de l'hôte monté, afin que Jenkins puisse exécuter des conteneurs Docker "frères" (sibling containers) plutôt que d'imbriquer Docker dans Docker.

### `Jenkinsfile`
Définit le pipeline en 3 étapes principales :
1. **Vérification du code source** — confirme la présence du dossier `juice-shop` dans le workspace ;
2. **SAST — Semgrep** — lance un conteneur `semgrep/semgrep` éphémère (`--rm`) qui analyse le code et produit `semgrep-report.json` ;
3. **SCA — OWASP Dependency-Check** — utilise l'outil configuré (`odcInstallation: 'DP-check'`) pour analyser les dépendances npm et générer un rapport multi-format (`--format ALL`) ;

puis, dans le bloc `post { always { ... } }`, un résumé par sévérité est extrait des deux rapports JSON via `jq`, avant l'envoi d'un e-mail HTML récapitulatif avec les rapports en pièce jointe.

## 8. Limites connues / points d'attention

- Sans clé API NVD, le scan Dependency-Check est nettement plus lent (accès à l'API NVD en mode non authentifié, plus limité).
- Le rapport Dependency-Check mélange les échelles de sévérité NVD (`LOW/MEDIUM/HIGH/CRITICAL`) et GitHub Security Advisories (`low/moderate/high/critical`) : un décompte brut par chaîne de caractères peut donc gonfler artificiellement le total de vulnérabilités si les deux échelles ne sont pas normalisées avant addition.

## 9. Documentation complémentaire

Le fichier **`Rapport_Automatisation_Jenkins_GitHub.pdf`** détaille pas à pas la configuration complète de l'infrastructure (captures d'écran à l'appui) : construction du conteneur Jenkins, intégration GitHub/SCM, automatisation par webhook via ngrok, et mise en place des notifications e-mail..
