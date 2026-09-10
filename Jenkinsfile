pipeline {
    agent any
    environment {
        DEST_EMAIL = 'ndiagadiouff@gmail.com'
    }
    stages {
        stage('1. Verification Code Source') {
            steps {
                echo "Code source vérifié dans le workspace."
                sh 'ls -la juice-shop'
            }
        }

        stage('2. SAST Scan - Semgrep') {
            steps {
                echo "Lancement du scan de sécurité SAST sur Juice Shop..."
                sh '''
                    docker run --rm \
                      -v devops-infra-jenkins_jenkins-data:/var/jenkins_home \
                      -w /var/jenkins_home/workspace/${JOB_NAME}/juice-shop \
                      semgrep/semgrep semgrep scan --config auto \
                      --json --output /var/jenkins_home/workspace/${JOB_NAME}/semgrep-report.json .
                '''
            }
        }

        stage('3. SCA Scan - OWASP Dependency-Check') {
            steps {
                echo "Lancement de l'analyse des dépendances (SCA) avec OWASP Dependency-Check..."
                dir('juice-shop') {
                    dependencyCheck(
                        odcInstallation: 'DP-check',
                        // nvdCredentialsId: 'nvd-api-key',   // décommenter une fois la clé NVD ajoutée dans Jenkins Credentials
                        additionalArguments: """
                            --project "${JOB_NAME}"
                            --scan .
                            --format ALL
                            --out ../dependency-check-report
                            --disableYarnAudit
                            --disableNodeAudit
                        """
                    )
                }
                dependencyCheckPublisher(
                    pattern: 'dependency-check-report/dependency-check-report.xml',
                    // Seuils : on ne bloque pas le build pour le TP, on remonte juste l'info
                    unstableTotalHigh: 0,
                    unstableTotalCritical: 0,
                    stopBuild: false
                )
                archiveArtifacts artifacts: 'dependency-check-report/**', allowEmptyArchive: true
            }
        }
    }

    post {
        always {
            script {
                // Résumé du nombre de vulnérabilités par sévérité, extrait du rapport JSON de Dependency-Check
                env.SCA_SUMMARY = sh(
                    script: '''
                        if [ -f dependency-check-report/dependency-check-report.json ]; then
                            jq -r '
                                [.dependencies[]?.vulnerabilities[]?.severity]
                                | group_by(.)
                                | map("\\(.[0] // "N/A"): \\(length)")
                                | join(" &nbsp;|&nbsp; ")
                            ' dependency-check-report/dependency-check-report.json
                        else
                            echo "Rapport SCA introuvable (voir logs)."
                        fi
                    ''',
                    returnStdout: true
                ).trim()

                env.SAST_SUMMARY = sh(
                    script: '''
                        if [ -f semgrep-report.json ]; then
                            jq -r '"\\(.results | length) findings"' semgrep-report.json
                        else
                            echo "Rapport SAST introuvable (voir logs)."
                        fi
                    ''',
                    returnStdout: true
                ).trim()
            }

            echo "Envoi du rapport consolidé par email..."
            emailext(
                to: "${DEST_EMAIL}",
                subject: "Rapport Sécurité Jenkins - ${JOB_NAME} #${BUILD_NUMBER} [${currentBuild.currentResult}]",
                mimeType: 'text/html',
                body: """
                    <div style="font-family:Arial,sans-serif;font-size:14px;color:#222;">
                        <h2 style="border-bottom:2px solid #333;padding-bottom:6px;">
                            🛡️ Pipeline DevSecOps — Juice Shop
                        </h2>
                        <table style="border-collapse:collapse;margin-bottom:16px;">
                            <tr><td style="padding:4px 10px;"><b>Job</b></td><td style="padding:4px 10px;">${JOB_NAME} #${BUILD_NUMBER}</td></tr>
                            <tr><td style="padding:4px 10px;"><b>Statut</b></td><td style="padding:4px 10px;">${currentBuild.currentResult}</td></tr>
                            <tr><td style="padding:4px 10px;"><b>URL</b></td><td style="padding:4px 10px;"><a href="${BUILD_URL}">${BUILD_URL}</a></td></tr>
                        </table>

                        <h3 style="background:#3B3B3B;color:#fff;padding:6px 10px;">🔍 SAST — Semgrep</h3>
                        <p style="padding-left:10px;">${env.SAST_SUMMARY}</p>

                        <h3 style="background:#3B3B3B;color:#fff;padding:6px 10px;">📦 SCA — OWASP Dependency-Check</h3>
                        <p style="padding-left:10px;">Vulnérabilités par sévérité : <b>${env.SCA_SUMMARY}</b></p>
                        <p style="padding-left:10px;">Rapport HTML détaillé et log complet en pièces jointes.</p>

                        <hr/>
                        <p style="color:gray;font-size:11px;">Jenkins DevSecOps Pipeline — généré automatiquement</p>
                    </div>
                """,
                attachmentsPattern: 'dependency-check-report/dependency-check-report.html, semgrep-report.json',
                attachLog: true
            )
        }
    }
}