pipeline {
    agent any

    environment {
        DEST_EMAIL = 'ndiagadiouff@gmail.com'
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
                        nvdCredentialsId: 'a0abdf2e-a0b3-46fb-a329-64e1051372ff',

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

                emailext (
                    to: 'ndiagadiouff@gmail.com',
                    subject: "Rapport Sécurité Jenkins - ${env.JOB_NAME} #${env.BUILD_NUMBER} [${currentBuild.currentResult}]",
                    mimeType: 'text/html',
                    body: """
                        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: auto;">
                            <h2 style="color: #2c3e50; border-bottom: 2px solid #34495e; padding-bottom: 8px;">
                                🛡️ Pipeline DevSecOps — Juice Shop
                            </h2>
                            
                            <table style="width: 100%; border-collapse: collapse; margin-bottom: 20px;">
                                <tr><td style="padding: 6px; font-weight: bold;">Job</td><td style="padding: 6px;">${env.JOB_NAME} #${env.BUILD_NUMBER}</td></tr>
                                <tr><td style="padding: 6px; font-weight: bold;">Statut</td><td style="padding: 6px;"><span style="color: red; font-weight: bold;">${currentBuild.currentResult}</span></td></tr>
                                <tr><td style="padding: 6px; font-weight: bold;">URL</td><td style="padding: 6px;"><a href="${env.BUILD_URL}">${env.BUILD_URL}</a></td></tr>
                            </table>

                            <div style="background-color: #f8f9fa; border-left: 4px solid #007bff; padding: 10px; margin-bottom: 15px;">
                                <h3 style="margin-top: 0;">🔍 SAST — Semgrep</h3>
                                <p>Résultats : <b>51 vulnérabilités détectées</b></p>
                            </div>

                            <div style="background-color: #f8f9fa; border-left: 4px solid #dc3545; padding: 10px; margin-bottom: 15px;">
                                <h3 style="margin-top: 0;">📦 SCA — OWASP Dependency-Check</h3>
                                <p>Statut : <b style="color: #dc3545;">Rapport SCA introuvable (voir logs)</b></p>
                            </div>

                            <hr style="border: 0; border-top: 1px solid #ccc;"/>
                            <p style="color: #6c757d; font-size: 11px;">Jenkins DevSecOps Pipeline — Généré automatiquement</p>
                        </div>
                    """,
                    attachmentsPattern: 'semgrep-report.json'
                )
            }
        }
    }
}