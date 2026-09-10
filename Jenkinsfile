pipeline {

    agent any

    environment {
        DEST_EMAIL = 'TON_EMAIL_ICI@gmail.com'
        SCA_REPORT_DIR = 'dependency-check-report'
    }

    stages {

        // ============================================================
        // STAGE 1 : VERIFICATION DU CODE SOURCE
        // ============================================================
        stage('1. Verification Code Source') {
            steps {
                echo "=== Verification du code source ==="

                sh '''
                    set -e

                    echo "Workspace : ${WORKSPACE}"
                    echo ""

                    echo "=== Contenu du workspace ==="
                    ls -lah

                    echo ""
                    echo "=== Contenu de Juice Shop ==="
                    ls -lah juice-shop

                    echo ""
                    echo "=== Verification package.json ==="
                    test -f juice-shop/package.json

                    echo "package.json present."
                '''
            }
        }


        // ============================================================
        // STAGE 2 : SAST - SEMGREP
        // ============================================================
        stage('2. SAST - Semgrep') {
            steps {
                echo "=== Lancement du scan SAST Semgrep ==="

                sh '''
                    set -e

                    rm -f semgrep-report.json

                    docker run --rm \
                      -v devops-infra-jenkins_jenkins-data:/var/jenkins_home \
                      -w /var/jenkins_home/workspace/${JOB_NAME}/juice-shop \
                      semgrep/semgrep \
                      semgrep scan \
                      --config auto \
                      --json \
                      --output /var/jenkins_home/workspace/${JOB_NAME}/semgrep-report.json \
                      .

                    echo ""
                    echo "=== Verification du rapport Semgrep ==="

                    test -f "${WORKSPACE}/semgrep-report.json"

                    ls -lh "${WORKSPACE}/semgrep-report.json"

                    echo ""
                    echo "=== Nombre de findings Semgrep ==="

                    jq '.results | length' \
                      "${WORKSPACE}/semgrep-report.json"
                '''
            }
        }


        // ============================================================
        // STAGE 3 : PREPARATION DES DEPENDANCES NPM
        // ============================================================
        stage('3. Preparation des dependances NPM') {
            steps {
                echo "=== Preparation des dependances NPM ==="

                sh '''
                    set -e

                    echo "=== Verification de package.json ==="

                    test -f "${WORKSPACE}/juice-shop/package.json"

                    echo "package.json present."

                    echo ""
                    echo "=== Installation des dependances avec Node.js ==="

                    docker run --rm \
                      -v "${WORKSPACE}/juice-shop:/app" \
                      -w /app \
                      node:24-bookworm \
                      npm install --ignore-scripts

                    echo ""
                    echo "=== Verification apres installation ==="

                    test -f "${WORKSPACE}/juice-shop/package-lock.json"

                    test -d "${WORKSPACE}/juice-shop/node_modules"

                    echo "package-lock.json : OK"
                    echo "node_modules      : OK"

                    echo ""
                    echo "=== Informations NPM ==="

                    docker run --rm \
                      -v "${WORKSPACE}/juice-shop:/app" \
                      -w /app \
                      node:24-bookworm \
                      npm --version

                    echo ""
                    echo "=== Nombre de dependances installees ==="

                    find "${WORKSPACE}/juice-shop/node_modules" \
                      -mindepth 1 \
                      -maxdepth 1 \
                      -type d | wc -l
                '''
            }
        }


        // ============================================================
        // STAGE 4 : SCA - OWASP DEPENDENCY-CHECK
        // ============================================================
        stage('4. SCA - OWASP Dependency-Check') {
            steps {
                echo "=== Lancement du scan SCA OWASP Dependency-Check ==="

                sh '''
                    set -e

                    rm -rf "${WORKSPACE}/${SCA_REPORT_DIR}"

                    mkdir -p "${WORKSPACE}/${SCA_REPORT_DIR}"
                '''

                dir('juice-shop') {

                    dependencyCheck(
                        odcInstallation: 'DP-check',
                        nvdCredentialsId: 'E9153CE4-A531-44C9-9102-CCFCD09FE4F5',
                        additionalArguments: """
                            --project "${JOB_NAME}"
                            --scan .
                            --format ALL
                            --out ../${SCA_REPORT_DIR}
                            --disableYarnAudit
                            --disableNodeAudit
                        """
                    )
                }

                sh '''
                    set -e

                    echo ""
                    echo "=== Verification des rapports Dependency-Check ==="

                    test -f "${WORKSPACE}/${SCA_REPORT_DIR}/dependency-check-report.xml"
                    test -f "${WORKSPACE}/${SCA_REPORT_DIR}/dependency-check-report.html"
                    test -f "${WORKSPACE}/${SCA_REPORT_DIR}/dependency-check-report.json"

                    echo ""
                    echo "Rapport XML : OK"
                    echo "Rapport HTML : OK"
                    echo "Rapport JSON : OK"

                    echo ""
                    echo "=== Liste des rapports ==="

                    ls -lh "${WORKSPACE}/${SCA_REPORT_DIR}"
                '''

                dependencyCheckPublisher(
                    pattern: 'dependency-check-report/dependency-check-report.xml',
                    unstableTotalHigh: 0,
                    unstableTotalCritical: 0,
                    stopBuild: false
                )
            }
        }


        // ============================================================
        // STAGE 5 : ANALYSE DES RAPPORTS
        // ============================================================
        stage('5. Analyse des rapports') {
            steps {
                script {

                    echo "=== Analyse des rapports de securite ==="


                    // ------------------------------------------------
                    // SAST
                    // ------------------------------------------------

                    env.SAST_TOTAL = sh(
                        script: '''
                            if [ -f "${WORKSPACE}/semgrep-report.json" ]; then
                                jq '.results | length' \
                                   "${WORKSPACE}/semgrep-report.json"
                            else
                                echo "0"
                            fi
                        ''',
                        returnStdout: true
                    ).trim()


                    env.SAST_SEVERITY = sh(
                        script: '''
                            if [ -f "${WORKSPACE}/semgrep-report.json" ]; then

                                jq -r '
                                    [
                                        .results[]?.extra?.severity
                                    ]
                                    | map(select(. != null))
                                    | group_by(.)
                                    | map(
                                        "\\(.[0]): \\(length)"
                                      )
                                    | join(" | ")
                                ' "${WORKSPACE}/semgrep-report.json"

                            else
                                echo "Rapport SAST introuvable"
                            fi
                        ''',
                        returnStdout: true
                    ).trim()


                    // ------------------------------------------------
                    // SCA
                    // ------------------------------------------------

                    env.SCA_TOTAL = sh(
                        script: '''
                            if [ -f "${WORKSPACE}/${SCA_REPORT_DIR}/dependency-check-report.json" ]; then

                                jq '
                                    [
                                        .dependencies[]?
                                        | .vulnerabilities[]?
                                    ]
                                    | length
                                ' "${WORKSPACE}/${SCA_REPORT_DIR}/dependency-check-report.json"

                            else
                                echo "0"
                            fi
                        ''',
                        returnStdout: true
                    ).trim()


                    env.SCA_SEVERITY = sh(
                        script: '''
                            if [ -f "${WORKSPACE}/${SCA_REPORT_DIR}/dependency-check-report.json" ]; then

                                jq -r '
                                    [
                                        .dependencies[]?
                                        | .vulnerabilities[]?
                                        | .severity
                                    ]
                                    | map(select(. != null))
                                    | if length == 0
                                      then
                                        "Aucune vulnerabilite identifiee"
                                      else
                                        group_by(.)
                                        | map(
                                            "\\(.[0]): \\(length)"
                                          )
                                        | join(" | ")
                                      end
                                ' "${WORKSPACE}/${SCA_REPORT_DIR}/dependency-check-report.json"

                            else
                                echo "Rapport SCA introuvable"
                            fi
                        ''',
                        returnStdout: true
                    ).trim()


                    echo ""
                    echo "=========================================="
                    echo "          RESULTATS DE SECURITE"
                    echo "=========================================="

                    echo ""
                    echo "SAST - Semgrep"
                    echo "Total findings : ${env.SAST_TOTAL}"
                    echo "Severites      : ${env.SAST_SEVERITY}"

                    echo ""
                    echo "SCA - Dependency-Check"
                    echo "Total vulnerabilites : ${env.SCA_TOTAL}"
                    echo "Severites            : ${env.SCA_SEVERITY}"

                    echo ""
                    echo "=========================================="
                }
            }
        }


        // ============================================================
        // STAGE 6 : ARCHIVAGE DES RAPPORTS
        // ============================================================
        stage('6. Archivage des rapports') {
            steps {

                echo "=== Archivage des rapports de securite ==="

                archiveArtifacts(
                    artifacts: '''
                        semgrep-report.json,
                        dependency-check-report/**
                    ''',
                    allowEmptyArchive: false
                )

                echo "Rapports archives avec succes."
            }
        }
    }


    // ================================================================
    // POST : ENVOI DU RAPPORT PAR EMAIL
    // ================================================================
    post {

        always {

            script {

                echo "=== Envoi du rapport de securite ==="

                emailext(
                    to: "${DEST_EMAIL}",

                    subject: "Rapport Securite Jenkins - ${JOB_NAME} #${BUILD_NUMBER} [${currentBuild.currentResult}]",

                    mimeType: 'text/html',

                    body: """
                        <html>

                        <body>

                        <h2>Rapport de securite Jenkins</h2>

                        <p>
                            <b>Projet :</b> ${JOB_NAME}<br>
                            <b>Build :</b> #${BUILD_NUMBER}<br>
                            <b>Statut :</b> ${currentBuild.currentResult}
                        </p>


                        <hr>

                        <h3>SAST - Semgrep</h3>

                        <p>
                            <b>Total des findings :</b>
                            ${env.SAST_TOTAL ?: 'N/A'}
                        </p>

                        <p>
                            <b>Severites :</b>
                            ${env.SAST_SEVERITY ?: 'N/A'}
                        </p>


                        <hr>

                        <h3>SCA - OWASP Dependency-Check</h3>

                        <p>
                            <b>Total des vulnerabilites identifiees :</b>
                            ${env.SCA_TOTAL ?: 'N/A'}
                        </p>

                        <p>
                            <b>Severites :</b>
                            ${env.SCA_SEVERITY ?: 'N/A'}
                        </p>

                        <p>
                            <i>
                            Attention : l'absence de vulnerabilite identifiee
                            ne signifie pas necessairement que les dependances
                            sont exemptes de vulnerabilites. Les resultats
                            dependent notamment de la qualite des informations
                            disponibles pour l'analyse.
                            </i>
                        </p>


                        <hr>

                        <h3>Rapports disponibles</h3>

                        <ul>
                            <li>Rapport Semgrep JSON</li>
                            <li>Rapport Dependency-Check HTML</li>
                            <li>Rapport Dependency-Check JSON</li>
                            <li>Rapport Dependency-Check XML</li>
                            <li>Rapport Dependency-Check CSV</li>
                            <li>Rapport Dependency-Check SARIF</li>
                        </ul>


                        <p>
                            Les rapports complets sont disponibles dans
                            les artefacts du build Jenkins.
                        </p>

                        </body>

                        </html>
                    """,

                    attachmentsPattern:
                        'dependency-check-report/dependency-check-report.html,semgrep-report.json',

                    attachLog: true
                )
            }
        }
    }
}