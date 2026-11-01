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

        stage('Dependency scan (Trivy)') {
            steps {
                sh '''
                    docker run --rm \
                      --volumes-from jenkins-setup-jenkins-1 \
                      -v trivy-cache:/root/.cache/ \
                      aquasec/trivy:latest \
                      rootfs --scanners vuln --severity HIGH,CRITICAL --exit-code 0 \
                      "$WORKSPACE/services/order-service/target"
                '''
            }
        }
    }
}