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

        stage('SAST (Semgrep)') {
            steps {
                sh 'semgrep scan --config p/java --config p/python --metrics=off services terraform/core/lambda'
            }
        }

        stage('IaC scan (Checkov)') {
            steps {
                sh 'checkov -d terraform --framework terraform --config-file terraform/.checkov.yaml --soft-fail --compact --quiet'
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