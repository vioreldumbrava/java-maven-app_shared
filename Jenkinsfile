#!/usr/bin/env groovy

pipeline {
    agent any
    tools {
        maven 'maven-3.10'
    }
    parameters {
        string(name: 'EC2_IP', defaultValue: '13.60.47.84', description: 'EC2 instance IP address')
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
        stage("build") {
            steps {
                script {
                    echo "Building the application..."
                    sh 'mvn package -DskipTests'
                }
            }
        }
        stage("deploy") {
            steps {
                script {
                    def dockerCmd = 'docker run -p 8080:8080 -d vioreldv2/learn-devops:v2'
                    sshagent(credentials: ['ec2-server-key']) {
                        sh "ssh -o StrictHostKeyChecking=no ec2-user@${params.EC2_IP} ${dockerCmd}"
                    }
                    echo "Deploying the application..."
                }
            }
        }
    }
}

