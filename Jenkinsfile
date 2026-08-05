pipeline {
    agent any

    stages {
        stage('1. Verification Code Source') {
            steps {
                echo "Code source vérifié dans le workspace."
                sh 'ls -la'
            }
        }

        stage('2. SAST Scan - Semgrep') {
            steps {
                echo "Lancement du scan de sécurité SAST sur Juice Shop..."
                sh '''
                    docker run --rm \
                      -v devops-infra-jenkins_jenkins-data:/var/jenkins_home \
                      -w "/var/jenkins_home/workspace/${JOB_NAME}/juice-shop" \
                      semgrep/semgrep semgrep scan --config auto
                '''
            }
        }
    }

    post {
        always {
            echo "Fin du pipeline."
        }
        success {
            echo "Analyse SAST terminée avec succès !"
        }
        failure {
            echo "Le pipeline a échoué."
        }
    }
}