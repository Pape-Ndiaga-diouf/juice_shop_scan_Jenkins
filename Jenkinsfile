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
                        -w "/var/jenkins_home/workspace/${JOB_NAME}/juice-shop" \
                        semgrep/semgrep \
                        semgrep scan \
                        --config auto \
                        --json \
                        --output "/var/jenkins_home/workspace/${JOB_NAME}/juice-shop/${SAST_REPORT}" \
                        .

                    echo ""
                    echo "=== Verification du rapport Semgrep ==="

                    test -f "${JUICE_SHOP_DIR}/${SAST_REPORT}"

                    cp "${JUICE_SHOP_DIR}/${SAST_REPORT}" \
                       "${WORKSPACE}/${SAST_REPORT}"

                    echo "Rapport Semgrep : PRESENT"

                    ls -lh "${WORKSPACE}/${SAST_REPORT}"

                    echo ""
                    echo "=== Nombre de findings Semgrep ==="

                    jq '.results | length' \
                       "${WORKSPACE}/${SAST_REPORT}"
                '''
            }
        }


        stage('3. Verification des dependances NPM') {
            steps {
                echo "=== Verification des dependances NPM ==="

                sh '''
                    set -e

                    echo "=== package.json ==="

                    test -f "${JUICE_SHOP_DIR}/package.json"
                    echo "package.json : PRESENT"

                    echo ""
                    echo "=== package-lock.json ==="

                    test -f "${JUICE_SHOP_DIR}/package-lock.json"
                    echo "package-lock.json : PRESENT"

                    echo ""
                    echo "=== Informations package-lock.json ==="

                    ls -lh "${JUICE_SHOP_DIR}/package-lock.json"

                    echo ""
                    echo "=== Verification NPM terminee ==="
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
                    nvdCredentialsId: 'db36c753-d0bb-4a46-8293-7f6ed9e0773e',
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

                    if [ -f "${WORKSPACE}/${SAST_REPORT}" ]; then

                        echo ""
                        echo "Nombre total de findings :"

                        jq '.results | length' \
                           "${WORKSPACE}/${SAST_REPORT}"

                        echo ""
                        echo "Severites :"

                        jq -r '
                            .results[]?.extra?.severity
                        ' "${WORKSPACE}/${SAST_REPORT}" \
                        | sort \
                        | uniq -c \
                        | sort -nr

                    else

                        echo "ERREUR : rapport SAST introuvable"
                        exit 1

                    fi


                    echo ""
                    echo "========================================="
                    echo "             RESULTATS SCA"
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
                        echo "Severites :"

                        jq -r '
                            .dependencies[]?
                            | .vulnerabilities[]?
                            | .severity
                        ' "${WORKSPACE}/${SCA_REPORT_DIR}/dependency-check-report.json" \
                        | sort \
                        | uniq -c \
                        | sort -nr

                    else

                        echo "ERREUR : rapport SCA introuvable"
                        exit 1

                    fi


                    echo ""
                    echo "========================================="
                    echo "             FIN DE L'ANALYSE"
                    echo "========================================="
                '''
            }
        }


        stage('6. Archivage des rapports') {
            steps {

                echo "=== Archivage des rapports ==="

                archiveArtifacts(
                    artifacts: """
                        ${SAST_REPORT},
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

                echo "=== Envoi du rapport de securite ==="

                def sastTotal = "N/A"
                def sastSeverity = "N/A"

                def scaTotal = "N/A"
                def scaSeverity = "N/A"


                // ==============================
                // SAST
                // ==============================

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
                                .results[]?.extra?.severity
                            ' '${SAST_REPORT}' |
                            sort |
                            uniq -c |
                            sort -nr |
                            tr '\\n' ' '
                        """,
                        returnStdout: true
                    ).trim()
                }


                // ==============================
                // SCA
                // ==============================

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


                // ==============================
                // EMAIL
                // ==============================

                emailext(
                    to: "${DEST_EMAIL}",

                    subject: "Rapport de Scan Securite Jenkins - Job: ${JOB_NAME} #${BUILD_NUMBER} [${currentBuild.currentResult}]",

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
                        Les rapports detailles sont disponibles
                        dans les artefacts du build Jenkins.
                        </p>

                        <p>
                        <b>Pipeline DevSecOps Jenkins</b>
                        </p>

                        </body>

                        </html>
                    """,

                    attachLog: true,

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