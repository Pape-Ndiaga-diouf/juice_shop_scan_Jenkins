pipeline {
    agent any

    environment {
        // Remplacez par l'URL de VOTRE dépôt GitHub
        REPO_URL = 'https://github.com/Pape-Ndiaga-diouf/juice_shop_scan_Jenkins.git'
        BRANCH_NAME = 'main'
    }

    stages {
        stage('1. Checkout Code Source') {
            steps {
                echo "Récupération du code source depuis GitHub..."
                // Nettoie l'espace de travail puis clone votre dépôt
                deleteDir()
                git branch: "${BRANCH_NAME}", url: "${REPO_URL}"
            }
        }

        stage('2. SAST Scan - Semgrep') {
            steps {
                echo "Lancement du scan de sécurité SAST..."
                // On utilise le volume nommé du conteneur Jenkins
                // /var/jenkins_home/workspace/NOM_DU_JOB correspond au dossier $(pwd)
                sh '''
                    docker run --rm \
                      -v devops-infra-jenkins_jenkins-data:/var/jenkins_home \
                      -w /var/jenkins_home/workspace/${JOB_NAME} \
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