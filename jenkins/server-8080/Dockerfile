# Image for the existing Jenkins on port 8080 (container "jenkins" on the VM).
# Stock Jenkins + Docker CLI, so pipelines can docker build/push using the host's Docker.
#
# Build & run on the VM:
#   docker build -t jenkins-docker:2.580.2-lts-jdk25 .
#   docker rm -f jenkins
#   docker run -d --name jenkins --restart unless-stopped -p 8080:8080 -p 50000:50000 \
#     -v jenkins_home:/var/jenkins_home \
#     -v /var/run/docker.sock:/var/run/docker.sock --group-add "$(stat -c %g /var/run/docker.sock)" \
#     jenkins-docker:2.580.2-lts-jdk25
FROM jenkins/jenkins:2.580.2-lts-jdk25
COPY --from=docker:cli /usr/local/bin/docker /usr/local/bin/docker
