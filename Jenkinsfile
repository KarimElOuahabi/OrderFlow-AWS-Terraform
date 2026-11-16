pipeline {
    agent any
    parameters {
        booleanParam(name: 'DEPLOY', defaultValue: false, description: 'Push the image to ECR and update ECS')
    }

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
                      zricethezav/gitleaks:v8.30.1 \
                      detect --source "$WORKSPACE" --redact --no-banner --exit-code 1
                '''
            }
        }

        stage('SAST (Semgrep)') {
            steps {
                sh 'semgrep scan --config p/java --config p/python --metrics=off --error services terraform/core/lambda'
            }
        }

        stage('IaC scan (Checkov)') {
            steps {
                sh 'checkov -d terraform --framework terraform --config-file terraform/.checkov.yaml --compact --quiet'
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
                      aquasec/trivy:0.76.2 \
                      image --input "$WORKSPACE/order-service-ci.tar" \
                      --scanners vuln --severity HIGH,CRITICAL --exit-code 1 --timeout 15m
                    rm -f "$WORKSPACE/order-service-ci.tar"
                '''
            }
        }

        stage('Push to ECR') {
            when { expression { params.DEPLOY } }
            steps {
                withCredentials([usernamePassword(credentialsId: 'aws-deployer',
                        usernameVariable: 'AWS_ACCESS_KEY_ID',
                        passwordVariable: 'AWS_SECRET_ACCESS_KEY')]) {
                    sh '''
                        REGISTRY=$(aws sts get-caller-identity --query Account --output text).dkr.ecr.us-east-1.amazonaws.com
                        aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $REGISTRY
                        docker tag order-service:ci $REGISTRY/orderflow-order-service:latest
                        docker tag order-service:ci $REGISTRY/orderflow-order-service:$BUILD_NUMBER
                        docker push $REGISTRY/orderflow-order-service:latest
                        docker push $REGISTRY/orderflow-order-service:$BUILD_NUMBER
                    '''
                }
            }
        }

        stage('Deploy to ECS') {
            when { expression { params.DEPLOY } }
            steps {
                withCredentials([usernamePassword(
                        credentialsId: 'aws-deployer',
                        usernameVariable: 'AWS_ACCESS_KEY_ID',
                        passwordVariable: 'AWS_SECRET_ACCESS_KEY')]) {
                    sh '''
                        aws ecs update-service --cluster orderflow-cluster --service order-service --force-new-deployment --region us-east-1
                    '''
                }
            }
        }
    }
}