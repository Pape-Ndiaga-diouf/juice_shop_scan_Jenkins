pipeline {
    agent any

    environment {
        DEST_EMAIL = 'TON_EMAIL_ICI'
        SCA_REPORT_DIR = 'dependency-check-report'
        SAST_REPORT = 'semgrep-report.json'
    }

    stages {

        stage('1. Verification Code Source') {
            steps {
                echo '=== Verification du code source ==='

                sh '''
                    set -e

                    echo "Workspace : $(pwd)"
                    echo "Contenu du workspace :"
                    ls -lah

                    echo "Contenu de juice-shop :"
                    ls -lah juice-shop
                '''
            }
        }

        stage('2. SAST - Semgrep') {
            steps {
                echo '=== Lancement du scan SAST Semgrep ==='

                sh '''
                    set -e

                    rm -f "${SAST_REPORT}"

                    docker run --rm \
                        -v devops-infra-jenkins_jenkins-data:/var/jenkins_home \
                        -w "/var/jenkins_home/workspace/${JOB_NAME}/juice-shop" \
                        semgrep/semgrep \
                        semgrep scan \
                        --config auto \
                        --json \
                        --output "/var/jenkins_home/workspace/${JOB_NAME}/${SAST_REPORT}" \
                        .

                    echo ""
                    echo "=== Verification du rapport Semgrep ==="

                    if [ ! -f "${WORKSPACE}/${SAST_REPORT}" ]; then
                        echo "ERREUR : rapport Semgrep absent."
                        exit 1
                    fi

                    ls -lh "${WORKSPACE}/${SAST_REPORT}"

                    echo ""
                    echo "=== Nombre total de findings ==="

                    jq '.results | length' "${WORKSPACE}/${SAST_REPORT}"
                '''
            }
        }

        stage('3. SCA - OWASP Dependency-Check') {
            steps {
                echo '=== Lancement du scan SCA Dependency-Check ==='

                dir('juice-shop') {

                    sh '''
                        rm -rf "../${SCA_REPORT_DIR}"
                        mkdir -p "../${SCA_REPORT_DIR}"
                    '''

                    dependencyCheck(
                        odcInstallation: 'DP-check',

                        // Remplace par l'ID réel de ta credential NVD
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

                echo '=== Verification des rapports Dependency-Check ==='

                sh '''
                    echo "Workspace actuel : $(pwd)"

                    echo ""
                    echo "=== Contenu du dossier SCA ==="

                    if [ -d "${SCA_REPORT_DIR}" ]; then
                        find "${SCA_REPORT_DIR}" -maxdepth 2 -type f -printf "%p (%s bytes)\\n"
                    else
                        echo "ERREUR : dossier ${SCA_REPORT_DIR} absent."
                    fi

                    echo ""
                    echo "=== Verification des fichiers ==="

                    if [ -f "${SCA_REPORT_DIR}/dependency-check-report.xml" ]; then
                        echo "OK : XML trouve"
                    else
                        echo "ATTENTION : XML absent"
                    fi

                    if [ -f "${SCA_REPORT_DIR}/dependency-check-report.html" ]; then
                        echo "OK : HTML trouve"
                    else
                        echo "ATTENTION : HTML absent"
                    fi

                    if [ -f "${SCA_REPORT_DIR}/dependency-check-report.json" ]; then
                        echo "OK : JSON trouve"
                    else
                        echo "ATTENTION : JSON absent"
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

        stage('4. Analyse des rapports') {
            steps {
                script {

                    echo '=== Analyse du rapport Semgrep ==='

                    env.SAST_SUMMARY = sh(
                        script: '''
                            if [ -f "${SAST_REPORT}" ]; then

                                jq -r '
                                    .results
                                    | group_by(.extra.severity)
                                    | map(
                                        "\\(.[0].extra.severity): \\(length)"
                                    )
                                    | join(" | ")
                                ' "${SAST_REPORT}"

                            else
                                echo "Rapport SAST introuvable"
                            fi
                        ''',
                        returnStdout: true
                    ).trim()

                    env.SAST_TOTAL = sh(
                        script: '''
                            if [ -f "${SAST_REPORT}" ]; then
                                jq '.results | length' "${SAST_REPORT}"
                            else
                                echo "0"
                            fi
                        ''',
                        returnStdout: true
                    ).trim()


                    echo '=== Analyse du rapport Dependency-Check ==='

                    env.SCA_SUMMARY = sh(
                        script: '''
                            if [ -f "${SCA_REPORT_DIR}/dependency-check-report.json" ]; then

                                jq -r '
                                    [
                                        .dependencies[]?.vulnerabilities[]?.severity
                                    ]
                                    | map(select(. != null))
                                    | group_by(.)
                                    | map(
                                        "\\(.[0]): \\(length)"
                                    )
                                    | join(" | ")
                                ' "${SCA_REPORT_DIR}/dependency-check-report.json"

                            else
                                echo "Rapport SCA introuvable"
                            fi
                        ''',
                        returnStdout: true
                    ).trim()


                    env.SCA_TOTAL = sh(
                        script: '''
                            if [ -f "${SCA_REPORT_DIR}/dependency-check-report.json" ]; then

                                jq '
                                    [
                                        .dependencies[]?.vulnerabilities[]?
                                    ]
                                    | length
                                ' "${SCA_REPORT_DIR}/dependency-check-report.json"

                            else
                                echo "0"
                            fi
                        ''',
                        returnStdout: true
                    ).trim()
                }
            }
        }

        stage('5. Archivage des rapports') {
            steps {

                archiveArtifacts(
                    artifacts: '''
                        semgrep-report.json,
                        dependency-check-report/*
                    ''',
                    allowEmptyArchive: true,
                    fingerprint: true
                )
            }
        }
    }

    post {

        always {

            script {

                echo '=== Preparation du rapport email ==='

                def buildStatus = currentBuild.currentResult

                emailext(
                    to: "${DEST_EMAIL}",

                    subject: "Rapport DevSecOps - ${JOB_NAME} #${BUILD_NUMBER} [${buildStatus}]",

                    mimeType: 'text/html',

                    body: """
                    <html>
                    <body style="font-family:Arial,sans-serif;color:#222;">

                        <h2 style="border-bottom:2px solid #333;padding-bottom:8px;">
                            🛡️ Pipeline DevSecOps - OWASP Juice Shop
                        </h2>

                        <table style="border-collapse:collapse;margin-bottom:20px;">
                            <tr>
                                <td style="padding:6px 15px 6px 0;">
                                    <b>Job</b>
                                </td>
                                <td>
                                    ${JOB_NAME} #${BUILD_NUMBER}
                                </td>
                            </tr>

                            <tr>
                                <td style="padding:6px 15px 6px 0;">
                                    <b>Statut</b>
                                </td>
                                <td>
                                    ${buildStatus}
                                </td>
                            </tr>

                            <tr>
                                <td style="padding:6px 15px 6px 0;">
                                    <b>Build</b>
                                </td>
                                <td>
                                    <a href="${BUILD_URL}">
                                        ${BUILD_URL}
                                    </a>
                                </td>
                            </tr>
                        </table>


                        <h3 style="background:#333;color:white;padding:8px;">
                            🔍 SAST - Semgrep
                        </h3>

                        <table style="border-collapse:collapse;width:100%;">

                            <tr>
                                <td style="padding:6px;">
                                    <b>Total findings</b>
                                </td>

                                <td style="padding:6px;">
                                    ${env.SAST_TOTAL}
                                </td>
                            </tr>

                            <tr>
                                <td style="padding:6px;">
                                    <b>Severity</b>
                                </td>

                                <td style="padding:6px;">
                                    ${env.SAST_SUMMARY}
                                </td>
                            </tr>

                        </table>


                        <h3 style="background:#333;color:white;padding:8px;">
                            📦 SCA - OWASP Dependency-Check
                        </h3>

                        <table style="border-collapse:collapse;width:100%;">

                            <tr>
                                <td style="padding:6px;">
                                    <b>Total vulnerabilities</b>
                                </td>

                                <td style="padding:6px;">
                                    ${env.SCA_TOTAL}
                                </td>
                            </tr>

                            <tr>
                                <td style="padding:6px;">
                                    <b>Severity</b>
                                </td>

                                <td style="padding:6px;">
                                    ${env.SCA_SUMMARY}
                                </td>
                            </tr>

                        </table>


                        <h3 style="background:#333;color:white;padding:8px;">
                            📎 Rapports
                        </h3>

                        <ul>
                            <li>Semgrep JSON</li>
                            <li>Dependency-Check HTML</li>
                            <li>Dependency-Check JSON</li>
                            <li>Dependency-Check XML</li>
                            <li>Log Jenkins complet</li>
                        </ul>


                        <hr>

                        <p style="color:gray;font-size:11px;">
                            Jenkins DevSecOps Pipeline -
                            OWASP Juice Shop
                        </p>

                    </body>
                    </html>
                    """,

                    attachmentsPattern: '''
                        semgrep-report.json,
                        dependency-check-report/dependency-check-report.html,
                        dependency-check-report/dependency-check-report.json,
                        dependency-check-report/dependency-check-report.xml
                    ''',

                    attachLog: true
                )
            }
        }
    }
}