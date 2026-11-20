#!/usr/bin.env groovy

pipeline {   
    agent any
    stages {
        stage("test") {
            steps {
                script {
                    echo "Testing the application..."

                }
            }
        }
        stage("build") {
            steps {
                script {
                    echo "Building the application..."
                }
            }
        }

        stage("deploy") {
            steps {
                script {
                    def dockerCmd = 'docker run -p 3080:3080 -d vioreldv2/learn-devops:v1'
                    sshagent(credentials: ['ec2-server-key'], executable: '') {
                    // some block
                    sh "ssh -o StrictHostKeyChecking=no ec2-user@16.171.161.33 ${dockerCmd}"
            }
                    echo "Deploying the application..."
                }
            }
        }               
    }
} 
