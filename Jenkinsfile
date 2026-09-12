// Plugins Jenkins requis :
// - Email Extension Plugin (email-ext) : fournit la step emailext
// - OWASP Dependency-Check Plugin : fournit dependencyCheck et dependencyCheckPublisher

pipeline {

    agent any

    environment {
        DEST_EMAIL = 'ndiagadiouff@gmail.com'
        SCA_REPORT_DIR = 'dependency-check-report'
        SAST_REPORT = 'semgrep-report.json'
        JUICE_SHOP_DIR = "${WORKSPACE}/juice-shop"
    }

    stages {

        stage('1. Verification Code Source') {
            steps {
                sh '''
                    echo "=== Verification du code source ==="

                    test -f "${JUICE_SHOP_DIR}/package.json" || {
                        echo "ERREUR : package.json introuvable"
                        exit 1
                    }

                    test -f "${JUICE_SHOP_DIR}/package-lock.json" || {
                        echo "ERREUR : package-lock.json introuvable"
                        exit 1
                    }

                    echo "Code source OK"
                '''
            }
        }

        stage('2. SAST Scan - Semgrep') {
            steps {
                sh '''
                    echo "=== Scan SAST avec Semgrep ==="

                    rm -f "${WORKSPACE}/${SAST_REPORT}"
                    rm -f "${JUICE_SHOP_DIR}/${SAST_REPORT}"

                    docker run --rm \
                        -v devops-infra-jenkins_jenkins-data:/var/jenkins_home \
                        -w "/var/jenkins_home/workspace/${JOB_NAME}/juice-shop" \
                        semgrep/semgrep \
                        semgrep scan \
                        --config auto \
                        --json \
                        --output "/var/jenkins_home/workspace/${JOB_NAME}/juice-shop/${SAST_REPORT}" \
                        .

                    test -f "${JUICE_SHOP_DIR}/${SAST_REPORT}" || {
                        echo "ERREUR : rapport Semgrep introuvable"
                        exit 1
                    }

                    cp "${JUICE_SHOP_DIR}/${SAST_REPORT}" "${WORKSPACE}/${SAST_REPORT}"

                    echo "Rapport Semgrep genere :"
                    ls -lh "${WORKSPACE}/${SAST_REPORT}"

                    echo "Nombre de findings :"
                    jq '.results | length' "${WORKSPACE}/${SAST_REPORT}"
                '''
            }
        }

        stage('3. Verification des dependances NPM') {
            steps {
                sh '''
                    echo "=== Installation de node_modules ==="

                    docker run --rm \
                        -v devops-infra-jenkins_jenkins-data:/var/jenkins_home \
                        -w "/var/jenkins_home/workspace/${JOB_NAME}/juice-shop" \
                        node:24-bookworm \
                        npm install --ignore-scripts --package-lock=true

                    echo ""
                    echo "=== Audit NPM ==="

                    docker run --rm \
                        -v devops-infra-jenkins_jenkins-data:/var/jenkins_home \
                        -w "/var/jenkins_home/workspace/${JOB_NAME}/juice-shop" \
                        node:24-bookworm \
                        npm audit || true
                '''
            }
        }

        stage('4. SCA - OWASP Dependency-Check') {
            steps {

                sh '''
                    echo "=== Preparation du rapport Dependency-Check ==="

                    rm -rf "${WORKSPACE}/${SCA_REPORT_DIR}"
                    mkdir -p "${WORKSPACE}/${SCA_REPORT_DIR}"
                '''

                dependencyCheck(
                    odcInstallation: 'DP-check',
                    nvdCredentialsId: 'db36c753-d0bb-4a46-8293-7f6ed9e0773e',
                    additionalArguments: """
                        --project "${JOB_NAME}"
                        --scan "${WORKSPACE}/juice-shop"
                        --format ALL
                        --out "${WORKSPACE}/${SCA_REPORT_DIR}"
                        --disableYarnAudit
                    """
                )

                sh '''
                    echo "=== Verification des rapports Dependency-Check ==="

                    test -f "${WORKSPACE}/${SCA_REPORT_DIR}/dependency-check-report.xml"
                    test -f "${WORKSPACE}/${SCA_REPORT_DIR}/dependency-check-report.html"
                    test -f "${WORKSPACE}/${SCA_REPORT_DIR}/dependency-check-report.json"

                    echo ""
                    echo "Rapports generes :"
                    ls -lh "${WORKSPACE}/${SCA_REPORT_DIR}/"
                '''

                dependencyCheckPublisher(
                    pattern: 'dependency-check-report/dependency-check-report.xml',
                    unstableTotalHigh: 0,
                    unstableTotalCritical: 0,
                    stopBuild: false
                )
            }
        }

        stage('5. Analyse des rapports') {
            steps {
                sh '''
                    echo "======================================"
                    echo " ANALYSE DES RAPPORTS DE SECURITE"
                    echo "======================================"

                    echo ""
                    echo "=== SEMGREP ==="

                    if [ -f "${WORKSPACE}/${SAST_REPORT}" ]; then

                        echo "Total findings :"
                        jq '.results | length' "${WORKSPACE}/${SAST_REPORT}"

                        echo ""
                        echo "Severites :"

                        jq -r '
                            .results[]?
                            | .extra?.severity // "UNKNOWN"
                        ' "${WORKSPACE}/${SAST_REPORT}" \
                        | sort \
                        | uniq -c \
                        | sort -nr

                    else
                        echo "Rapport Semgrep introuvable"
                    fi

                    echo ""
                    echo "=== DEPENDENCY-CHECK ==="

                    if [ -f "${WORKSPACE}/${SCA_REPORT_DIR}/dependency-check-report.json" ]; then

                        echo "Total vulnerabilites :"

                        jq '
                            [.dependencies[]? | .vulnerabilities[]?]
                            | length
                        ' "${WORKSPACE}/${SCA_REPORT_DIR}/dependency-check-report.json"

                        echo ""
                        echo "Severites :"

                        jq -r '
                            .dependencies[]?
                            | .vulnerabilities[]?
                            | .severity // "UNKNOWN"
                        ' "${WORKSPACE}/${SCA_REPORT_DIR}/dependency-check-report.json" \
                        | sort \
                        | uniq -c \
                        | sort -nr

                    else
                        echo "Rapport Dependency-Check introuvable"
                    fi
                '''
            }
        }

        stage('5bis. Generation des rapports de synthese') {
            steps {
                sh '''
                    set -e

                    echo "======================================"
                    echo " GENERATION DES RAPPORTS DE SYNTHESE"
                    echo "======================================"

                    # ============================================================
                    # RAPPORT DE SYNTHESE SEMGREP
                    # ============================================================

                    echo ""
                    echo "=== Generation du rapport Semgrep ==="

                    cat > "${WORKSPACE}/semgrep-summary.html" <<EOF
<!DOCTYPE html>
<html lang="fr">
<head>
<meta charset="UTF-8">
<title>Rapport SAST - Semgrep</title>

<style>
body {
    font-family: Arial, sans-serif;
    margin: 40px;
    background: #f5f5f5;
    color: #222;
}

.container {
    background: white;
    padding: 30px;
    border-radius: 8px;
}

h1 {
    color: #333;
}

h2 {
    margin-top: 30px;
}

table {
    width: 100%;
    border-collapse: collapse;
    margin-top: 20px;
}

th, td {
    border: 1px solid #ddd;
    padding: 8px;
    text-align: left;
}

th {
    background: #eee;
}

.summary {
    font-size: 18px;
    margin: 10px 0;
}
</style>

</head>

<body>

<div class="container">

<h1>Rapport de securite - SAST Semgrep</h1>

<p><b>Projet :</b> ${JOB_NAME}</p>
<p><b>Build :</b> #${BUILD_NUMBER}</p>

<h2>Resume</h2>

<div class="summary">
<b>Total des findings :</b>
$(jq '.results | length' "${WORKSPACE}/${SAST_REPORT}")
</div>

<h2>Repartition par severite</h2>

<table>
<tr>
    <th>Severite</th>
    <th>Nombre</th>
</tr>

$(jq -r '
    .results[]
    | .extra?.severity // "UNKNOWN"
' "${WORKSPACE}/${SAST_REPORT}" \
| sort \
| uniq -c \
| sort -nr \
| awk '{print "<tr><td>" $2 "</td><td>" $1 "</td></tr>"}')

</table>

<h2>Details des findings</h2>

<table>

<tr>
    <th>Severite</th>
    <th>Regle</th>
    <th>Fichier</th>
    <th>Ligne</th>
    <th>Message</th>
</tr>

$(jq -r '
    .results[] |
    "<tr>" +
    "<td>" + (.extra?.severity // "UNKNOWN") + "</td>" +
    "<td>" + (.check_id // "UNKNOWN") + "</td>" +
    "<td>" + (.path // "UNKNOWN") + "</td>" +
    "<td>" + ((.start?.line // 0) | tostring) + "</td>" +
    "<td>" + (.extra?.message // "") + "</td>" +
    "</tr>"
' "${WORKSPACE}/${SAST_REPORT}")

</table>

</div>

</body>
</html>
EOF


                    # ============================================================
                    # RAPPORT DE SYNTHESE DEPENDENCY-CHECK
                    # ============================================================

                    echo ""
                    echo "=== Generation du rapport Dependency-Check ==="

                    cat > "${WORKSPACE}/dependency-check-summary.html" <<EOF
<!DOCTYPE html>
<html lang="fr">

<head>

<meta charset="UTF-8">

<title>Rapport SCA - OWASP Dependency-Check</title>

<style>

body {
    font-family: Arial, sans-serif;
    margin: 40px;
    background: #f5f5f5;
    color: #222;
}

.container {
    background: white;
    padding: 30px;
    border-radius: 8px;
}

h1 {
    color: #333;
}

h2 {
    margin-top: 30px;
}

table {
    width: 100%;
    border-collapse: collapse;
    margin-top: 20px;
}

th, td {
    border: 1px solid #ddd;
    padding: 8px;
    text-align: left;
}

th {
    background: #eee;
}

.summary {
    font-size: 18px;
    margin: 10px 0;
}

</style>

</head>

<body>

<div class="container">

<h1>Rapport de securite - SCA Dependency-Check</h1>

<p><b>Projet :</b> ${JOB_NAME}</p>
<p><b>Build :</b> #${BUILD_NUMBER}</p>

<h2>Resume</h2>

<div class="summary">

<b>Total des vulnerabilites :</b>

$(jq '
    [.dependencies[]? | .vulnerabilities[]?]
    | length
' "${WORKSPACE}/${SCA_REPORT_DIR}/dependency-check-report.json")

</div>

<h2>Repartition par severite</h2>

<table>

<tr>
    <th>Severite</th>
    <th>Nombre</th>
</tr>

$(jq -r '
    .dependencies[]?
    | .vulnerabilities[]?
    | .severity // "UNKNOWN"
' "${WORKSPACE}/${SCA_REPORT_DIR}/dependency-check-report.json" \
| sort \
| uniq -c \
| sort -nr \
| awk '{print "<tr><td>" $2 "</td><td>" $1 "</td></tr>"}')

</table>


<h2>Details des vulnerabilites</h2>

<table>

<tr>
    <th>Dependance</th>
    <th>Version</th>
    <th>Severite</th>
    <th>Vulnerabilite</th>
</tr>

$(jq -r '
    .dependencies[]? as $dep
    | $dep.vulnerabilities[]?
    | "<tr>" +
      "<td>" + ($dep.fileName // $dep.pkgName // $dep.name // "UNKNOWN") + "</td>" +
      "<td>" + ($dep.version // "UNKNOWN") + "</td>" +
      "<td>" + (.severity // "UNKNOWN") + "</td>" +
      "<td>" + (.name // "UNKNOWN") + "</td>" +
      "</tr>"
' "${WORKSPACE}/${SCA_REPORT_DIR}/dependency-check-report.json")

</table>

</div>

</body>

</html>
EOF


                    # ============================================================
                    # VERIFICATION
                    # ============================================================

                    echo ""
                    echo "======================================"
                    echo " VERIFICATION DES RAPPORTS"
                    echo "======================================"

                    test -f "${WORKSPACE}/semgrep-summary.html"
                    test -f "${WORKSPACE}/dependency-check-summary.html"

                    echo ""
                    echo "Rapport Semgrep :"
                    ls -lh "${WORKSPACE}/semgrep-summary.html"

                    echo ""
                    echo "Rapport Dependency-Check :"
                    ls -lh "${WORKSPACE}/dependency-check-summary.html"

                '''
            }
        }

        stage('6. Archivage des rapports') {
            steps {

                archiveArtifacts(
                    artifacts: """
                        ${SAST_REPORT},
                        semgrep-summary.html,
                        dependency-check-summary.html,
                        ${SCA_REPORT_DIR}/**
                    """,
                    allowEmptyArchive: false,
                    fingerprint: true
                )
            }
        }
    }

    post {

        always {

            script {

                echo "======================================"
                echo " ENVOI DU RAPPORT DE SECURITE"
                echo "======================================"

                def sastTotal = "N/A"
                def sastSeverity = "N/A"

                def scaTotal = "N/A"
                def scaSeverity = "N/A"


                // ============================================================
                // RECUPERATION DES STATISTIQUES SEMGREP
                // ============================================================

                if (fileExists("${SAST_REPORT}")) {

                    sastTotal = sh(
                        script: """
                            jq '.results | length' '${SAST_REPORT}'
                        """,
                        returnStdout: true
                    ).trim()

                    sastSeverity = sh(
                        script: """
                            jq -r '
                                .results[]?
                                | .extra?.severity // "UNKNOWN"
                            ' '${SAST_REPORT}' \
                            | sort \
                            | uniq -c \
                            | sort -nr \
                            | tr '\\n' ' '
                        """,
                        returnStdout: true
                    ).trim()
                }


                // ============================================================
                // RECUPERATION DES STATISTIQUES DEPENDENCY-CHECK
                // ============================================================

                if (fileExists("${SCA_REPORT_DIR}/dependency-check-report.json")) {

                    scaTotal = sh(
                        script: """
                            jq '
                                [.dependencies[]? | .vulnerabilities[]?]
                                | length
                            ' '${SCA_REPORT_DIR}/dependency-check-report.json'
                        """,
                        returnStdout: true
                    ).trim()

                    scaSeverity = sh(
                        script: """
                            jq -r '
                                .dependencies[]?
                                | .vulnerabilities[]?
                                | .severity // "UNKNOWN"
                            ' '${SCA_REPORT_DIR}/dependency-check-report.json' \
                            | sort \
                            | uniq -c \
                            | sort -nr \
                            | tr '\\n' ' '
                        """,
                        returnStdout: true
                    ).trim()
                }


                // ============================================================
                // VERIFICATION DES PIECES JOINTES
                // ============================================================

                echo "======================================"
                echo " VERIFICATION DES PIECES JOINTES"
                echo "======================================"

                sh '''
                    echo ""
                    echo "Workspace :"
                    pwd

                    echo ""
                    echo "Fichiers de synthese :"
                    ls -lh semgrep-summary.html dependency-check-summary.html

                    echo ""
                    echo "Taille Semgrep :"
                    du -h semgrep-summary.html

                    echo ""
                    echo "Taille Dependency-Check :"
                    du -h dependency-check-summary.html
                '''


                // ============================================================
                // ENVOI EMAIL
                // ============================================================

                emailext(
                    to: "${DEST_EMAIL}",

                    subject: "Rapport Securite Jenkins - Job: ${JOB_NAME} #${BUILD_NUMBER}",

                    mimeType: 'text/html',

                    body: """
                        <html>

                        <body>

                        <h2>Rapport de securite DevSecOps</h2>

                        <p>
                            <b>Projet :</b> ${JOB_NAME}<br>
                            <b>Build :</b> #${BUILD_NUMBER}<br>
                            <b>Statut :</b> ${currentBuild.currentResult}<br>
                            <b>URL :</b> ${BUILD_URL}
                        </p>

                        <hr>

                        <h3>SAST - Semgrep</h3>

                        <p>
                            <b>Total findings :</b> ${sastTotal}<br>
                            <b>Severites :</b> ${sastSeverity}
                        </p>

                        <h3>SCA - OWASP Dependency-Check</h3>

                        <p>
                            <b>Total vulnerabilites :</b> ${scaTotal}<br>
                            <b>Severites :</b> ${scaSeverity}
                        </p>

                        <hr>

                        <p>
                            Les rapports detailles sont disponibles dans les
                            pieces jointes de cet email ainsi que dans les
                            artefacts du build Jenkins.
                        </p>

                        </body>

                        </html>
                    """,

                    attachLog: false,

                    // IMPORTANT :
                    // Une seule ligne, sans retour a la ligne
                    // et sans espaces inutiles.
                    attachmentsPattern: 'semgrep-summary.html,dependency-check-summary.html'
                )
            }
        }
    }
}
//