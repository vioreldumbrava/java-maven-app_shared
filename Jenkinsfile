#!/usr/bin/env groovy

pipeline {
    agent any
    parameters {
        string(name: 'EC2_IP', defaultValue: '13.60.47.84', description: 'EC2 instance IP address')
    }
    environment {
        // Same Docker Hub repo as the Java app (free plan allows 1 private repo), separate tag prefix
        APP_VERSION = "django-v1.${BUILD_NUMBER}"
        IMAGE_NAME  = "vioreldv2/learn-devops:django-v1.${BUILD_NUMBER}"
        TEST_IMAGE  = "django-app-test:${BUILD_NUMBER}"
    }
    stages {
        stage("test") {
            steps {
                script {
                    echo "Running the Django tests inside a Docker build..."
                    sh 'docker build --target test -t "$TEST_IMAGE" .'
                }
            }
            post {
                always {
                    sh 'docker rmi "$TEST_IMAGE" || true'
                }
            }
        }
        stage("build and push image") {
            steps {
                script {
                    echo "Building the Docker image ${IMAGE_NAME}..."
                    sh 'docker build --build-arg APP_VERSION="$APP_VERSION" -t "$IMAGE_NAME" .'
                    withCredentials([usernamePassword(credentialsId: 'docker-hub-repo', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
                        sh 'echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin'
                        sh 'docker push "$IMAGE_NAME"'
                        sh 'docker logout'
                    }
                    // Free disk on the Jenkins host; the image now lives on Docker Hub
                    sh 'docker rmi "$IMAGE_NAME" || true'
                }
            }
        }
        stage("deploy") {
            steps {
                script {
                    echo "Deploying ${IMAGE_NAME} to EC2..."
                    // Own container name and port, so it runs next to the Java app (java-maven-app on 8080)
                    def dockerComposeCmd = "docker-compose -f docker-compose.yaml up --detach"
                    sshagent(credentials: ['ec2-server-key']) {
                        sh "scp docker-compose.yaml ec2-user@${params.EC2_IP}:~/docker-compose.yaml"
                        sh "ssh -o StrictHostKeyChecking=no ec2-user@${params.EC2_IP} '${dockerComposeCmd}'"
                    }
                }
            }
        }
    }
}
