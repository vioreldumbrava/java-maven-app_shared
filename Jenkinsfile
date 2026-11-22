#!/usr/bin/env groovy

pipeline {
    agent any
    tools {
        maven 'maven-3.10'
    }
    parameters {
        string(name: 'EC2_IP', defaultValue: '13.60.47.84', description: 'EC2 instance IP address')
    }
    environment {
        // New tag per build, so EC2 always pulls the image that was just built
        IMAGE_NAME = "vioreldv2/learn-devops:v2.${BUILD_NUMBER}"
    }
    stages {
        stage("test") {
            steps {
                script {
                    echo "Testing the application..."
                    sh 'mvn test'
                }
            }
        }
        stage("build jar") {
            steps {
                script {
                    echo "Building the application..."
                    sh 'mvn package -DskipTests'
                }
            }
        }
        stage("build and push image") {
            steps {
                script {
                    echo "Building the Docker image ${IMAGE_NAME}..."
                    sh 'docker build -t "$IMAGE_NAME" .'
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
                    // Replace the previous container so port 8080 is free
                    def dockerCmd = "docker rm -f java-maven-app 2>/dev/null; docker run -d --name java-maven-app --restart unless-stopped -p 8080:8080 ${IMAGE_NAME}"
                    sshagent(credentials: ['ec2-server-key']) {
                        sh "ssh -o StrictHostKeyChecking=no ec2-user@${params.EC2_IP} '${dockerCmd}'"
                    }
                }
            }
        }
    }
}
