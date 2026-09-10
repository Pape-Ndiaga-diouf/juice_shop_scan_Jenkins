pipeline {
    agent any

    environment {
        DEST_EMAIL = 'ndiagadiouff@gmail.com'
        SCA_REPORT_DIR = 'dependency-check-report'
        SAST_REPORT = 'semgrep-report.json'
        JUICE_SHOP_DIR = "${WORKSPACE}/juice-shop"
        NVD_CREDENTIALS_ID = 'a0abdf2e-a0b3-46fb-a329-64e1051372ff'
    }

    stages {
        stage('1. Verification Code Source') {
            steps {
                echo "=== Verification du code source Juice Shop ==="
                sh '''
                    set -e
                    echo "=== Contenu du workspace ==="
                    ls -la
                    echo ""
                    echo "=== Verification du repertoire Juice Shop ==="
                    test -d "${JUICE_SHOP_DIR}"
                    echo "juice-shop : PRESENT"
                    test -f "${JUICE_SHOP_DIR}/package.json"
                    echo "package.json : PRESENT"
                    test -f "${JUICE_SHOP_DIR}/package-lock.json"
                    echo "package-lock.json : PRESENT"
                    echo ""
                    echo "=== Verification terminee ==="
                '''
            }
        }

        stage('2. SAST Scan - Semgrep') {
            steps {
                echo "=== Lancement du scan SAST Semgrep ==="
                sh '''
                    set -e
                    echo "=== Nettoyage ancien rapport ==="
                    rm -f "${WORKSPACE}/${SAST_REPORT}"
                    rm -f "${JUICE_SHOP_DIR}/${SAST_REPORT}"

                    echo ""
                    echo "=== Lancement de Semgrep ==="

                    docker run --rm \
                        -v devops-infra-jenkins_jenkins-data:/var/jenkins_home \
                        -w /var/jenkins_home/workspace/${JOB_NAME}/juice-shop \
                        semgrep/semgrep \
                        semgrep scan \
                        --config auto \
                        --json \
                        --output /var/jenkins_home/workspace/${JOB_NAME}/juice-shop/${SAST_REPORT} \
                        .

                    echo ""
                    echo "=== Verification du rapport Semgrep ==="
                    test -f "${JUICE_SHOP_DIR}/${SAST_REPORT}"
                    cp "${JUICE_SHOP_DIR}/${SAST_REPORT}" "${WORKSPACE}/${SAST_REPORT}"
                    echo "Rapport Semgrep : PRESENT"
                    ls -lh "${WORKSPACE}/${SAST_REPORT}"

                    echo ""
                    echo "=== Nombre de findings Semgrep ==="
                    jq '.results | length' "${WORKSPACE}/${SAST_REPORT}"
                '''
            }
        }

        stage('3. Preparation des dependances NPM') {
            steps {
                echo "=== Installation temporaire des dependances NPM ==="
                sh '''
                    set -e

                    echo "=== Verification package.json ==="
                    test -f "${JUICE_SHOP_DIR}/package.json"
                    echo "package.json : PRESENT"

                    echo ""
                    echo "=== Verification package-lock.json ==="
                    test -f "${JUICE_SHOP_DIR}/package-lock.json"
                    echo "package-lock.json : PRESENT"

                    echo ""
                    echo "=== Installation de node_modules ==="

                    docker run --rm \
                        -v devops-infra-jenkins_jenkins-data:/var/jenkins_home \
                        -w /var/jenkins_home/workspace/${JOB_NAME}/juice-shop \
                        node:24-bookworm \
                        npm install --ignore-scripts --package-lock=true

                    echo ""
                    echo "=== Verification node_modules ==="
                    test -d "${JUICE_SHOP_DIR}/node_modules"
                    echo "node_modules : PRESENT"

                    echo ""
                    echo "=== Preparation NPM terminee ==="
                '''
            }
        }

        stage('4. SCA - OWASP Dependency-Check') {
            steps {
                echo "=== Lancement du scan SCA Dependency-Check ==="

                sh '''
                    set -e
                    echo "=== Nettoyage ancien rapport SCA ==="
                    rm -rf "${WORKSPACE}/${SCA_REPORT_DIR}"
                    mkdir -p "${WORKSPACE}/${SCA_REPORT_DIR}"
                '''

                dependencyCheck(
                    odcInstallation: 'DP-check',
                    nvdCredentialsId: "${NVD_CREDENTIALS_ID}",
                    additionalArguments: """
                        --project "${JOB_NAME}"
                        --scan "${WORKSPACE}/juice-shop"
                        --format ALL
                        --out "${WORKSPACE}/${SCA_REPORT_DIR}"
                        --disableYarnAudit
                    """
                )

                sh '''
                    set -e
                    echo ""
                    echo "=== Verification des rapports Dependency-Check ==="
                    test -f "${SCA_REPORT_DIR}/dependency-check-report.xml"
                    echo "XML : PRESENT"
                    test -f "${SCA_REPORT_DIR}/dependency-check-report.html"
                    echo "HTML : PRESENT"
                    test -f "${SCA_REPORT_DIR}/dependency-check-report.json"
                    echo "JSON : PRESENT"
                    echo ""
                    echo "=== Fichiers generes ==="
                    ls -lh "${SCA_REPORT_DIR}"
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
                    echo "             RESULTATS SAST"
                    echo "========================================="

                    test -f "${WORKSPACE}/${SAST_REPORT}"

                    echo ""
                    echo "Nombre total de findings :"
                    jq '.results | length' "${WORKSPACE}/${SAST_REPORT}"

                    echo ""
                    echo "Severites :"
                    jq -r '.results[]?.extra?.severity // "UNKNOWN"' "${WORKSPACE}/${SAST_REPORT}" |
                        sort | uniq -c | sort -nr

                    echo ""
                    echo "========================================="
                    echo "             RESULTATS SCA"
                    echo "========================================="

                    test -f "${SCA_REPORT_DIR}/dependency-check-report.json"

                    echo ""
                    echo "Nombre total de vulnerabilites :"
                    jq '[.dependencies[]? | .vulnerabilities[]?] | length' \
                        "${SCA_REPORT_DIR}/dependency-check-report.json"

                    echo ""
                    echo "Severites :"
                    jq -r '
                        .dependencies[]?
                        | .vulnerabilities[]?
                        | .severity // "UNKNOWN"
                    ' "${SCA_REPORT_DIR}/dependency-check-report.json" |
                        sort | uniq -c | sort -nr

                    echo ""
                    echo "========================================="
                    echo "             FIN DE L ANALYSE"
                    echo "========================================="
                '''
            }
        }

        stage('6. Archivage des rapports') {
            steps {
                echo "=== Archivage des rapports ==="
                archiveArtifacts(
                    artifacts: 'semgrep-report.json,dependency-check-report/*',
                    allowEmptyArchive: false,
                    fingerprint: true
                )
            }
        }
    }

    post {
        always {
            script {
                echo "=== Envoi du rapport de securite ==="

                def semgrepTotal = "N/A"
                def semgrepSeverities = "N/A"
                def scaTotal = "N/A"
                def scaSeverities = "N/A"

                if (fileExists("${SAST_REPORT}")) {
                    semgrepTotal = sh(
                        script: "jq '.results | length' '${SAST_REPORT}'",
                        returnStdout: true
                    ).trim()

                    semgrepSeverities = sh(
                        script: """
                            jq -r '.results[]?.extra?.severity // "UNKNOWN"' '${SAST_REPORT}' |
                            sort | uniq -c | sort -nr | tr '\\n' ' '
                        """,
                        returnStdout: true
                    ).trim()
                }

                if (fileExists("${SCA_REPORT_DIR}/dependency-check-report.json")) {
                    scaTotal = sh(
                        script: """
                            jq '[.dependencies[]? | .vulnerabilities[]?] | length' \
                                '${SCA_REPORT_DIR}/dependency-check-report.json'
                        """,
                        returnStdout: true
                    ).trim()

                    scaSeverities = sh(
                        script: """
                            jq -r '
                                .dependencies[]?
                                | .vulnerabilities[]?
                                | .severity // "UNKNOWN"
                            ' '${SCA_REPORT_DIR}/dependency-check-report.json' |
                            sort | uniq -c | sort -nr | tr '\\n' ' '
                        """,
                        returnStdout: true
                    ).trim()

                    if (!scaSeverities) {
                        scaSeverities = "Aucune vulnerabilite detectee"
                    }
                }

                emailext(
                    to: "${DEST_EMAIL}",
                    subject: "Rapport de Scan DevSecOps Jenkins - Job: ${JOB_NAME} #${BUILD_NUMBER} [${currentBuild.currentResult}]",
                    mimeType: 'text/html',
                    attachmentsPattern: 'semgrep-report.json,dependency-check-report/dependency-check-report.html,dependency-check-report/dependency-check-report.json',
                    body: """
                        <html>
                        <body>
                        <h2>Rapport de securite DevSecOps</h2>

                        <h3>SAST - Semgrep</h3>
                        <p><b>Total findings :</b> ${semgrepTotal}</p>
                        <p><b>Severites :</b> ${semgrepSeverities}</p>

                        <h3>SCA - OWASP Dependency-Check</h3>
                        <p><b>Total vulnerabilites :</b> ${scaTotal}</p>
                        <p><b>Severites :</b> ${scaSeverities}</p>

                        <hr>

                        <p>
                        <b>Job Jenkins :</b> ${JOB_NAME}<br>
                        <b>Build :</b> #${BUILD_NUMBER}<br>
                        <b>Statut :</b> ${currentBuild.currentResult}<br>
                        <b>URL :</b> ${BUILD_URL}
                        </p>

                        <p>
                        Les rapports detailles sont joints a cet email.
                        Les autres formats generes par Dependency-Check
                        restent disponibles dans les artefacts Jenkins.
                        </p>
                        </body>
                        </html>
                    """
                )

                echo "=== Email envoye ==="
            }
        }

        cleanup {
            echo "=== Nettoyage de node_modules ==="
            sh '''
                rm -rf "${WORKSPACE}/juice-shop/node_modules" || true
            '''
        }
    }
}
