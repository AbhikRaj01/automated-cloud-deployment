
pipeline {
    agent any

    environment {
        KUBECONFIG = 'C:\\ProgramData\\Jenkins\\.kube-config'
        MINIKUBE_HOME = 'C:\\ProgramData\\Jenkins'
        PATH = "C:\\Program Files\\Docker\\Docker\\resources\\bin;C:\\Program Files\\Kubernetes\\Minikube;${env.PATH}"
        IMAGE_NAME = 'cloud-dashboard'
        IMAGE_TAG = '1.0'
    }

    stages {
        stage('Preflight Check') {
            steps {
                echo 'Checking Jenkins environment...'
                bat 'whoami'
                bat 'docker info --format "{{.ServerVersion}}"'
                bat 'kubectl config current-context'
                bat 'kubectl get nodes'
                bat 'minikube status -p minikube'
            }
        }

        stage('Checkout') {
            steps {
                echo 'Source code checked out from GitHub'
            }
        }

        stage('Build Docker Image') {
            steps {
                bat 'docker build -t %IMAGE_NAME%:%IMAGE_TAG% ./application'
            }
        }

        stage('Load Image into Minikube') {
            steps {
                bat 'minikube image load %IMAGE_NAME%:%IMAGE_TAG% -p minikube'
            }
        }

        stage('Deploy to Kubernetes') {
            steps {
                bat 'kubectl apply -f k8s/deployment.yaml'
                bat 'kubectl rollout restart deployment/cloud-dashboard'
                bat 'kubectl rollout status deployment/cloud-dashboard --timeout=120s'
            }
        }

        stage('Verify Deployment') {
            steps {
                bat 'kubectl get pods'
                bat 'kubectl get services'
            }
        }
    }

    post {
        success {
            echo 'CI/CD Pipeline completed successfully!'
        }
        failure {
            echo 'Pipeline failed. Check the console output.'
        }
    }
}
