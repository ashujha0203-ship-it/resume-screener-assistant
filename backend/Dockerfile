
# Stage 1: Build the Spring Boot application
FROM maven:3.10.0-eclipse-temurin-27 AS build

WORKDIR /app

COPY pom.xml .
COPY src ./src

# Compile for Java 25 and package the application.
RUN mvn -B clean package -DskipTests

# Stage 2: Run the application using Java 25
FROM eclipse-temurin:25-jre

WORKDIR /app

COPY --from=build /app/target/resume-screener-backend-0.0.1-SNAPSHOT.jar app.jar

EXPOSE 8080

ENTRYPOINT ["java", "-XX:MaxRAMPercentage=75.0", "-jar", "app.jar"]
