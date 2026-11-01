pipeline {
    agent any

    stages {
        stage('Check tools') {
            steps {
                sh 'git --version'
                sh 'java -version || echo "no java"'
                sh 'docker --version || echo "no docker"'
                sh 'ls services/order-service'
            }
        }

        stage('Build and test') {
            steps {
                dir('services/order-service') {
                    sh 'chmod +x mvnw'
                    sh './mvnw -B clean package "-Dtest=!OrderServiceApplicationTests"'
                }
            }
        }

        stage('Secret scan (Gitleaks)') {
            steps {
                sh '''
                    docker run --rm \
                      --volumes-from jenkins-setup-jenkins-1 \
                      zricethezav/gitleaks:latest \
                      detect --source "$WORKSPACE" --redact --no-banner
                '''
            }
        }

        stage('Docker build') {
            steps {
                dir('services/order-service') {
                    sh 'docker build -t order-service:ci .'
                }
            }
        }

        stage('Image scan (Trivy)') {
            steps {
                sh '''
                    docker save order-service:ci -o "$WORKSPACE/order-service-ci.tar"
                    docker run --rm \
                      --volumes-from jenkins-setup-jenkins-1 \
                      -v trivy-cache:/root/.cache/ \
                      aquasec/trivy:latest \
                      image --input "$WORKSPACE/order-service-ci.tar" \
                      --scanners vuln --severity HIGH,CRITICAL --exit-code 1 --timeout 15m
                    rm -f "$WORKSPACE/order-service-ci.tar"
                '''
            }
        }
    }
}