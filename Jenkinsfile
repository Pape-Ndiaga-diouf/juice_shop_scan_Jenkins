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
                      semgrep/semgrep semgrep scan --config auto .
                '''
            }
        }
    }

    post {
        always {
            echo "Envoi du rapport par email..."
            emailext (
                to: "${DEST_EMAIL}",
                subject: "Rapport de Scan SAST Jenkins - Job: ${JOB_NAME} #${BUILD_NUMBER} [${currentBuild.currentResult}]",
                body: """
Bonjour,

Le build #${BUILD_NUMBER} de la tâche '${JOB_NAME}' est terminé.

- Statut du build : ${currentBuild.currentResult}
- URL du build : ${BUILD_URL}

Vous trouverez ci-joint la sortie console complète contenant les résultats du scan Semgrep.

Cordialement,
Jenkins DevSecOps Pipeline
""",
                attachLog: true
            )
        }
    }
}