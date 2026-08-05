pipeline {
    agent any

    environment {
        // ID des identifiants créés dans Jenkins
        CREDENTIALS_ID = '41bb071f-4637-45aa-863d-d6e5f9e57f48'
    }

    stages {
        stage('1. Verification Code Source') {
            steps {
                echo "Code source déjà récupéré depuis GitHub via la configuration SCM."
                sh 'ls -la'
            }
        }

        stage('2. SAST Scan - Semgrep') {
            steps {
                echo "Lancement du scan de sécurité SAST..."
                // Utilisation du volume nommé de Jenkins pour scanner l'espace de travail
                sh '''
                    docker run --rm \
                      -v devops-infra-jenkins_jenkins-data:/var/jenkins_home \
                      -w /var/jenkins_home/workspace/"${JOB_NAME}" \
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