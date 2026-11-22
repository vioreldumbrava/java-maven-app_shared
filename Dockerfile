# Runtime image for the Spring Boot jar built by `mvn package` (pom targets Java 25)
FROM eclipse-temurin:25-jre

WORKDIR /app
COPY target/java-maven-app-*.jar app.jar

EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
