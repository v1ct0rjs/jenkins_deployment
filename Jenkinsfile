pipeline {
    agent any

    environment {
        GIT_CREDENTIALS = 'gitlab-pat'
        DOCKER_CREDS    = credentials('dockerhub-creds')
        SONAR_SCANNER_HOME = tool name: 'SonarQubeScanner'
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
                    DOCKERHUB_USER="$DOCKER_CREDS_USR" \
                    DOCKERHUB_PASS="$DOCKER_CREDS_PSW" \
                    ./dockerhub_push.sh
                '''
            }
        }

        stage('Verify Images') {
            steps {
                sh "docker images | grep '${env.DOCKER_CREDS_USR}'"
            }
        }

        stage('SonarQube Analysis') {
            steps {
                withSonarQubeEnv('MySonarQube') {
                    sh """
                        ${SONAR_SCANNER_HOME}/bin/sonar-scanner \
                          -Dsonar.projectKey=demo_project \
                          -Dsonar.sources=.
                    """
                }
            }
        }

        //stage('Quality Gate') {
        //    steps {
        //        waitForQualityGate abortPipeline: true
        //    }
        //}
    }
}

