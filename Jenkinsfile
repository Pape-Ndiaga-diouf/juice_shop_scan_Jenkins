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
                    echo ""

                    echo "=== Contenu du workspace ==="
                    ls -lah

                    echo ""
                    echo "=== Contenu de Juice Shop ==="
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

                    test -f "${WORKSPACE}/${SAST_REPORT}"

                    ls -lh "${WORKSPACE}/${SAST_REPORT}"

                    echo ""
                    echo "=== Nombre de findings Semgrep ==="

                    jq '.results | length' "${WORKSPACE}/${SAST_REPORT}"
                '''
            }
        }


        stage('3. Preparation des dependances NPM') {
            steps {
                echo '=== Preparation des dependances NPM ==='

                dir('juice-shop') {

                    sh '''
                        set -e

                        echo "=== Verification Node.js / NPM ==="

                        node --version
                        npm --version

                        echo ""
                        echo "=== Installation des dependances NPM ==="

                        npm install --ignore-scripts

                        echo ""
                        echo "=== Verification package-lock.json ==="

                        if [ -f package-lock.json ]; then
                            echo "OK : package-lock.json present"
                        else
                            echo "ERREUR : package-lock.json absent"
                            exit 1
                        fi

                        echo ""
                        echo "=== Verification node_modules ==="

                        if [ -d node_modules ]; then
                            echo "OK : node_modules present"
                        else
                            echo "ERREUR : node_modules absent"
                            exit 1
                        fi

                        echo ""
                        echo "=== Preparation NPM terminee ==="
                    '''
                }
            }
        }


        stage('4. SCA - OWASP Dependency-Check') {
            steps {
                echo '=== Lancement du scan SCA ==='

                dir('juice-shop') {

                    sh '''
                        rm -rf "../${SCA_REPORT_DIR}"
                        mkdir -p "../${SCA_REPORT_DIR}"
                    '''

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

                echo '=== Verification des rapports Dependency-Check ==='

                sh '''
                    echo ""
                    echo "=== Fichiers generes ==="

                    find "${SCA_REPORT_DIR}" \
                        -maxdepth 2 \
                        -type f \
                        -printf "%p (%s bytes)\\n"

                    echo ""

                    if [ -f "${SCA_REPORT_DIR}/dependency-check-report.xml" ]; then
                        echo "OK : XML present"
                    else
                        echo "ERREUR : XML absent"
                        exit 1
                    fi

                    if [ -f "${SCA_REPORT_DIR}/dependency-check-report.html" ]; then
                        echo "OK : HTML present"
                    else
                        echo "ERREUR : HTML absent"
                        exit 1
                    fi

                    if [ -f "${SCA_REPORT_DIR}/dependency-check-report.json" ]; then
                        echo "OK : JSON present"
                    else
                        echo "ERREUR : JSON absent"
                        exit 1
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
                script {

                    echo '=== Analyse Semgrep ==='

                    env.SAST_TOTAL = sh(
                        script: '''
                            jq '.results | length' "${SAST_REPORT}"
                        ''',
                        returnStdout: true
                    ).trim()


                    env.SAST_SUMMARY = sh(
                        script: '''
                            jq -r '
                                [
                                    .results[]
                                    | .extra.severity
                                ]
                                | group_by(.)
                                | map(
                                    "\\(.[0]): \\(length)"
                                )
                                | join(" | ")
                            ' "${SAST_REPORT}"
                        ''',
                        returnStdout: true
                    ).trim()


                    echo '=== Analyse Dependency-Check ==='

                    env.SCA_TOTAL = sh(
                        script: '''
                            jq '
                                [
                                    .dependencies[]?
                                    | .vulnerabilities[]?
                                ]
                                | length
                            ' "${SCA_REPORT_DIR}/dependency-check-report.json"
                        ''',
                        returnStdout: true
                    ).trim()


                    env.SCA_SUMMARY = sh(
                        script: '''
                            jq -r '
                                [
                                    .dependencies[]?
                                    | .vulnerabilities[]?
                                    | .severity
                                ]
                                | map(select(. != null))
                                | if length == 0 then
                                    "Aucune vulnerabilite identifiee"
                                  else
                                    group_by(.)
                                    | map(
                                        "\\(.[0]): \\(length)"
                                    )
                                    | join(" | ")
                                  end
                            ' "${SCA_REPORT_DIR}/dependency-check-report.json"
                        ''',
                        returnStdout: true
                    ).trim()
                }
            }
        }


        stage('6. Archivage des rapports') {
            steps {

                archiveArtifacts(
                    artifacts: '''
                        semgrep-report.json,
                        dependency-check-report/dependency-check-report.html,
                        dependency-check-report/dependency-check-report.json,
                        dependency-check-report/dependency-check-report.xml
                    ''',

                    allowEmptyArchive: false,
                    fingerprint: true
                )
            }
        }
    }


    post {

        always {

            script {

                echo '=== Envoi du rapport de securite ==='

                emailext(
                    to: "${DEST_EMAIL}",

                    subject: "Rapport DevSecOps - ${JOB_NAME} #${BUILD_NUMBER} [${currentBuild.currentResult}]",

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
                                    ${currentBuild.currentResult}
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


                        <!-- SAST -->

                        <h3 style="background:#333;color:white;padding:8px;">
                            🔍 SAST - Semgrep
                        </h3>


                        <table style="border-collapse:collapse;width:100%;">

                            <tr>
                                <td style="padding:7px;">
                                    <b>Total findings</b>
                                </td>

                                <td style="padding:7px;">
                                    ${env.SAST_TOTAL}
                                </td>
                            </tr>


                            <tr>
                                <td style="padding:7px;">
                                    <b>Severity</b>
                                </td>

                                <td style="padding:7px;">
                                    ${env.SAST_SUMMARY}
                                </td>
                            </tr>

                        </table>


                        <!-- SCA -->

                        <h3 style="background:#333;color:white;padding:8px;margin-top:20px;">
                            📦 SCA - OWASP Dependency-Check
                        </h3>


                        <table style="border-collapse:collapse;width:100%;">

                            <tr>
                                <td style="padding:7px;">
                                    <b>Total vulnerabilities</b>
                                </td>

                                <td style="padding:7px;">
                                    ${env.SCA_TOTAL}
                                </td>
                            </tr>


                            <tr>
                                <td style="padding:7px;">
                                    <b>Result</b>
                                </td>

                                <td style="padding:7px;">
                                    ${env.SCA_SUMMARY}
                                </td>
                            </tr>

                        </table>


                        <h3 style="background:#333;color:white;padding:8px;margin-top:20px;">
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