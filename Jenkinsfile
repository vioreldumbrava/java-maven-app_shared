#!/usr/bin/env groovy

pipeline {
    agent any
    parameters {
        string(name: 'EC2_IP', defaultValue: '16.171.230.252', description: 'EC2 instance IP address')
    }
    environment {
        // Amazon ECR private repository (AWS console: ECR > Repositories > my-app)
        AWS_REGION   = "eu-north-1"
        ECR_REGISTRY = "177203142220.dkr.ecr.${AWS_REGION}.amazonaws.com"
        APP_VERSION  = "django-v1.${BUILD_NUMBER}"
        IMAGE_NAME   = "${ECR_REGISTRY}/my-app:django-v1.${BUILD_NUMBER}"
        TEST_IMAGE   = "django-app-test:${BUILD_NUMBER}"
        // The AWS CLI runs as a container, so nothing has to be installed in Jenkins
        AWS_CLI      = "amazon/aws-cli:2.38.0"
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
                    // 'aws-ecr-credentials': "Username with password" credential,
                    // username = AWS access key ID, password = AWS secret access key
                    withCredentials([usernamePassword(credentialsId: 'aws-ecr-credentials', usernameVariable: 'AWS_ACCESS_KEY_ID', passwordVariable: 'AWS_SECRET_ACCESS_KEY')]) {
                        // Same as step 1 of the ECR "Push commands": get a login token (valid 12 h)
                        // and log Docker in with it. "-e NAME" passes the key from the environment,
                        // so it never appears in the command line or the log.
                        sh '''
                            docker run --rm -e AWS_ACCESS_KEY_ID -e AWS_SECRET_ACCESS_KEY "$AWS_CLI" \
                                ecr get-login-password --region "$AWS_REGION" \
                                | docker login --username AWS --password-stdin "$ECR_REGISTRY"
                        '''
                        sh 'docker push "$IMAGE_NAME"'
                        sh 'docker logout "$ECR_REGISTRY"'
                    }
                    // Free disk on the Jenkins host; the image now lives in ECR
                    sh 'docker rmi "$IMAGE_NAME" || true'
                }
            }
        }
        stage("deploy") {
            environment {
                // Folder on EC2 that holds docker-compose.yaml, server-cmds.sh and .env
                DEPLOY_DIR = "django-app"
                SSH_TARGET = "ec2-user@${params.EC2_IP}"
            }
            steps {
                script {
                    echo "Deploying ${IMAGE_NAME} to EC2 with docker-compose..."
                    withCredentials([
                        // 'postgres-password' is a "Secret text" credential
                        string(credentialsId: 'postgres-password', variable: 'POSTGRES_PASSWORD'),
                        // deploy.sh uses these to log EC2's Docker in to ECR before the pull
                        usernamePassword(credentialsId: 'aws-ecr-credentials', usernameVariable: 'AWS_ACCESS_KEY_ID', passwordVariable: 'AWS_SECRET_ACCESS_KEY')
                    ]) {
                        sshagent(credentials: ['ec2-server-key']) {
                            // deploy.sh reads the credentials, ECR_REGISTRY, AWS_REGION, AWS_CLI
                            // and DEPLOY_DIR from the environment.
                            // Single quotes: the shell (not Groovy) expands the variables.
                            sh 'bash deploy.sh "$SSH_TARGET" "$IMAGE_NAME"'
                        }
                    }
                }
            }
        }
    }
}
