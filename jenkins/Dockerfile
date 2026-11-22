# pom.xml compiles for Java 25, so run Jenkins (and therefore `mvn`) on JDK 25.
FROM jenkins/jenkins:lts-jdk25

USER root

# Maven on PATH for `sh 'mvn ...'` in the Jenkinsfile
ARG MAVEN_VERSION=3.9.11
RUN curl -fsSL "https://archive.apache.org/dist/maven/maven-3/${MAVEN_VERSION}/binaries/apache-maven-${MAVEN_VERSION}-bin.tar.gz" \
      | tar -xz -C /opt \
 && ln -s "/opt/apache-maven-${MAVEN_VERSION}" /opt/maven
ENV MAVEN_HOME=/opt/maven
ENV PATH="/opt/maven/bin:${PATH}"

# Docker CLI, only needed by Jenkinsfile-SharedLibrary (buildImage/dockerPush).
# It talks to the host daemon only if you mount the socket (see docker-compose.yml).
COPY --from=docker:cli /usr/local/bin/docker /usr/local/bin/docker

USER jenkins

# Install plugins at build time
COPY plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN jenkins-plugin-cli --plugin-file /usr/share/jenkins/ref/plugins.txt

# Skip the setup wizard (admin user comes from JCasC) and tell JCasC where its YAML lives
ENV JAVA_OPTS="-Djenkins.install.runSetupWizard=false"
ENV CASC_JENKINS_CONFIG=/var/jenkins_casc
