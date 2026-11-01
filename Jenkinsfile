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
    }
}