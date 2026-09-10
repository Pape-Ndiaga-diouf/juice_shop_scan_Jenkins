pipeline {

    agent any

    environment {
        SCA_REPORT_DIR = 'dependency-check-report'
        SAST_REPORT = 'semgrep-report.json'
    }

    stages {

        stage('1. Verification du code source') {
            steps {
                echo "=== Verification du code source Juice Shop ==="

                sh '''
                    set -e

                    echo "=== Contenu du workspace ==="
                    ls -la

                    echo ""
                    echo "=== Verification de Juice Shop ==="

                    test -f "${WORKSPACE}/juice-shop/package.json"
                    echo "package.json : PRESENT"

                    test -f "${WORKSPACE}/juice-shop/package-lock.json"
                    echo "package-lock.json : PRESENT"

                    echo ""
                    echo "=== Code source Juice Shop present ==="
                '''
            }
        }

        stage('2. SAST - Semgrep') {
            steps {
                echo "=== Analyse SAST avec Semgrep ==="

                sh '''
                    set +e

                    rm -f "${WORKSPACE}/${SAST_REPORT}"

                    docker run --rm \
                        -v "${WORKSPACE}/juice-shop:/src" \
                        semgrep/semgrep \
                        semgrep scan \
                        --config=auto \
                        --json \
                        --output=/src/../${SAST_REPORT} \
                        /src

                    SEMGREP_EXIT=$?

                    echo ""
                    echo "=== Verification du rapport Semgrep ==="

                    if [ -f "${WORKSPACE}/${SAST_REPORT}" ]; then
                        ls -lh "${WORKSPACE}/${SAST_REPORT}"

                        echo ""
                        echo "=== Nombre de findings Semgrep ==="
                        jq '.results | length' "${WORKSPACE}/${SAST_REPORT}"
                    else
                        echo "ERREUR : rapport Semgrep absent"
                        exit 1
                    fi

                    # Semgrep peut retourner un code non nul lorsqu'il trouve
                    # des vulnerabilites. On ne fait donc pas echouer le pipeline
                    # uniquement pour cette raison.

                    echo ""
                    echo "Code retour Semgrep : ${SEMGREP_EXIT}"

                    exit 0
                '''
            }
        }

        stage('3. Verification des dependances NPM') {
            steps {
                echo "=== Verification des dependances NPM ==="

                sh '''
                    set -e

                    echo "=== Verification de package.json ==="

                    test -f "${WORKSPACE}/juice-shop/package.json"
                    echo "package.json : PRESENT"

                    echo ""
                    echo "=== Verification de package-lock.json ==="

                    test -f "${WORKSPACE}/juice-shop/package-lock.json"
                    echo "package-lock.json : PRESENT"

                    echo ""
                    echo "=== Taille du package-lock.json ==="

                    ls -lh "${WORKSPACE}/juice-shop/package-lock.json"

                    echo ""
                    echo "=== Preparation des dependances terminee ==="
                '''
            }
        }

        stage('4. SCA - OWASP Dependency-Check') {
            steps {
                echo "=== Analyse SCA avec OWASP Dependency-Check ==="

                sh '''
                    set -e

                    rm -rf "${WORKSPACE}/${SCA_REPORT_DIR}"
                    mkdir -p "${WORKSPACE}/${SCA_REPORT_DIR}"
                '''

                dependencyCheck(
                    odcInstallation: 'DP-check',
                    nvdCredentialsId: 'E9153CE4-A531-44C9-9102-CCFCD09FE4F5',
                    additionalArguments: """
                        --project "${JOB_NAME}"
                        --scan "${WORKSPACE}/juice-shop"
                        --format ALL
                        --out "${WORKSPACE}/${SCA_REPORT_DIR}"
                        --disableYarnAudit
                        --disableNodeAudit
                    """
                )

                sh '''
                    set -e

                    echo ""
                    echo "=== Verification des rapports Dependency-Check ==="

                    if [ -f "${WORKSPACE}/${SCA_REPORT_DIR}/dependency-check-report.xml" ]; then
                        echo "dependency-check-report.xml : PRESENT"
                    else
                        echo "ERREUR : rapport XML absent"
                        exit 1
                    fi

                    if [ -f "${WORKSPACE}/${SCA_REPORT_DIR}/dependency-check-report.html" ]; then
                        echo "dependency-check-report.html : PRESENT"
                    fi

                    if [ -f "${WORKSPACE}/${SCA_REPORT_DIR}/dependency-check-report.json" ]; then
                        echo "dependency-check-report.json : PRESENT"
                    fi
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
                echo "=== Analyse des resultats de securite ==="

                sh '''
                    set -e

                    echo ""
                    echo "========================================="
                    echo "           RESULTATS SAST"
                    echo "========================================="

                    if [ -f "${WORKSPACE}/${SAST_REPORT}" ]; then

                        echo ""
                        echo "Nombre total de findings :"

                        jq '.results | length' \
                            "${WORKSPACE}/${SAST_REPORT}"

                        echo ""
                        echo "Severites Semgrep :"

                        jq -r '
                            .results[]?.extra?.severity
                        ' "${WORKSPACE}/${SAST_REPORT}" \
                        | sort \
                        | uniq -c \
                        | sort -nr

                    else
                        echo "Rapport SAST introuvable"
                    fi


                    echo ""
                    echo "========================================="
                    echo "           RESULTATS SCA"
                    echo "========================================="

                    if [ -f "${WORKSPACE}/${SCA_REPORT_DIR}/dependency-check-report.json" ]; then

                        echo ""
                        echo "Nombre total de vulnerabilites :"

                        jq '
                            [
                                .dependencies[]?
                                | .vulnerabilities[]?
                            ] | length
                        ' "${WORKSPACE}/${SCA_REPORT_DIR}/dependency-check-report.json"

                        echo ""
                        echo "Severites Dependency-Check :"

                        jq -r '
                            .dependencies[]?
                            | .vulnerabilities[]?
                            | .severity
                        ' "${WORKSPACE}/${SCA_REPORT_DIR}/dependency-check-report.json" \
                        | sort \
                        | uniq -c \
                        | sort -nr

                    else
                        echo "Rapport SCA introuvable"
                    fi

                    echo ""
                    echo "========================================="
                    echo "       FIN DE L'ANALYSE"
                    echo "========================================="
                '''
            }
        }

        stage('6. Archivage des rapports') {
            steps {
                echo "=== Archivage des rapports ==="

                archiveArtifacts artifacts: """
                    ${SAST_REPORT},
                    ${SCA_REPORT_DIR}/**
                """,
                allowEmptyArchive: false,
                fingerprint: true
            }
        }
    }

    post {

        always {

            script {

                echo "=== Envoi du rapport de securite ==="

                def sastTotal = "N/A"
                def sastSeverity = "N/A"

                def scaTotal = "N/A"
                def scaSeverity = "N/A"


                if (fileExists("${SAST_REPORT}")) {

                    sastTotal = sh(
                        script: """
                            jq '.results | length' '${SAST_REPORT}'
                        """,
                        returnStdout: true
                    ).trim()

                    sastSeverity = sh(
                        script: """
                            jq -r '.results[]?.extra?.severity' '${SAST_REPORT}' |
                            sort |
                            uniq -c |
                            sort -nr |
                            tr '\\n' ' '
                        """,
                        returnStdout: true
                    ).trim()
                }


                if (fileExists(
                    "${SCA_REPORT_DIR}/dependency-check-report.json"
                )) {

                    scaTotal = sh(
                        script: """
                            jq '
                                [
                                    .dependencies[]?
                                    | .vulnerabilities[]?
                                ] | length
                            ' '${SCA_REPORT_DIR}/dependency-check-report.json'
                        """,
                        returnStdout: true
                    ).trim()

                    scaSeverity = sh(
                        script: """
                            jq -r '
                                .dependencies[]?
                                | .vulnerabilities[]?
                                | .severity
                            ' '${SCA_REPORT_DIR}/dependency-check-report.json' |
                            sort |
                            uniq -c |
                            sort -nr |
                            tr '\\n' ' '
                        """,
                        returnStdout: true
                    ).trim()
                }


                emailext(
                    subject: "Rapport securite Jenkins - ${JOB_NAME} #${BUILD_NUMBER}",
                    to: "ndiagadiouff@gmail.com",
                    mimeType: 'text/html',

                    body: """
                        <html>
                        <body>

                        <h2>Rapport de securite</h2>

                        <p>
                            <b>Projet :</b> ${JOB_NAME}<br>
                            <b>Build :</b> #${BUILD_NUMBER}<br>
                            <b>Statut :</b> ${currentBuild.currentResult}
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
                            Les rapports detailles sont disponibles
                            dans les artefacts Jenkins.
                        </p>

                        </body>
                        </html>
                    """,

                    attachmentsPattern: """
                        ${SAST_REPORT},
                        ${SCA_REPORT_DIR}/*.html,
                        ${SCA_REPORT_DIR}/*.json,
                        ${SCA_REPORT_DIR}/*.xml,
                        ${SCA_REPORT_DIR}/*.csv,
                        ${SCA_REPORT_DIR}/*.sarif
                    """
                )
            }
        }
    }
}