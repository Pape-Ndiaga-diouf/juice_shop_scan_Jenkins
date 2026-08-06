pipeline {
    agent any

    environment {
        // Remplacez par votre adresse email de destination
        DEST_EMAIL = 'votre-email@gmail.com'
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
                      semgrep/semgrep semgrep scan --config auto .
                '''
            }
        }
    }

    post {
        always {
            echo "Envoi du rapport par email..."
            mail to: "${DEST_EMAIL}",
                 subject: "Rapport de Build Jenkins - Job: ${JOB_NAME} #${BUILD_NUMBER} [${currentBuild.currentResult}]",
                 body: """
Bonjour,

Le build #${BUILD_NUMBER} de la tâche '${JOB_NAME}' est terminé.

Statut du build : ${currentBuild.currentResult}
URL du build : ${BUILD_URL}

--- Début de la sortie console du scan ---
${BUILD_LOGS}
--- Fin de la sortie console ---

Cordialement,
Jenkins CI/CD
"""
        }
    }
}