pipeline {
    agent any

    environment {
        GIT_CREDENTIALS = 'gitlab-pat'
        DOCKER_CREDS = credentials('dockerhub-creds')
    }

    stages {
        stage('Checkout') {
            steps {
                git branch: 'main',
                    url: 'http://gitlab/root/demo_project.git',
                    credentialsId: "${GIT_CREDENTIALS}"
            }
        }

        stage('Build & Push Docker Images') {
            steps {
                sh '''
                    chmod +x dockerhub_push.sh
                    # Usamos las variables expuestas por 'credentials(...)':
                    #   $DOCKER_CREDS_USR = usuario de DockerHub
                    #   $DOCKER_CREDS_PSW = contraseña de DockerHub
                    DOCKERHUB_USER="$DOCKER_CREDS_USR" \
                    DOCKERHUB_PASS="$DOCKER_CREDS_PSW" \
                    ./dockerhub_push.sh
                '''
            }
        }

        stage('Verify Images') {
            steps {
                // Verifica que las imágenes se hayan creado localmente
                sh "docker images | grep '${env.DOCKER_CREDS_USR}'"
            }
        }
    }
}

