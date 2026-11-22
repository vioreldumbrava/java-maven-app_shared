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
            environment {
                // Folder on EC2 that holds docker-compose.yaml and .env
                DEPLOY_DIR = "django-app"
                SSH_TARGET = "ec2-user@${params.EC2_IP}"
            }
            steps {
                script {
                    echo "Deploying ${IMAGE_NAME} to EC2 with docker-compose..."
                    // 'postgres-password' is a "Secret text" credential in Jenkins
                    withCredentials([string(credentialsId: 'postgres-password', variable: 'POSTGRES_PASSWORD')]) {
                        sshagent(credentials: ['ec2-server-key']) {
                            // Single quotes: the shell (not Groovy) expands the variables,
                            // so the password never ends up in the Groovy string or the log
                            sh '''
                                SSH_OPTS="-o StrictHostKeyChecking=no"
                                ssh $SSH_OPTS "$SSH_TARGET" "mkdir -p ~/$DEPLOY_DIR"
                                scp $SSH_OPTS docker-compose.yaml "$SSH_TARGET:~/$DEPLOY_DIR/docker-compose.yaml"

                                # Write .env on EC2 through stdin, readable only by ec2-user.
                                # docker-compose reads it automatically from the same folder.
                                printf 'IMAGE_NAME=%s\\nPOSTGRES_PASSWORD=%s\\n' "$IMAGE_NAME" "$POSTGRES_PASSWORD" \
                                    | ssh $SSH_OPTS "$SSH_TARGET" "umask 077 && cat > ~/$DEPLOY_DIR/.env"

                                # Pull the new image, then (re)create only what changed.
                                # --wait: fail the build if a container doesn't become healthy/running
                                ssh $SSH_OPTS "$SSH_TARGET" "cd ~/$DEPLOY_DIR && docker-compose pull django-app && docker-compose up -d --wait"
                            '''
                        }
                    }
                }
            }
        }
    }
}
