# Multi-stage build using official Eclipse Temurin / Maven images
FROM maven:3.9-eclipse-temurin-17 AS build
WORKDIR /build

COPY pom.xml .
RUN mvn dependency:go-offline -B

COPY src/ ./src/
RUN mvn package -DskipTests -B

# Runtime stage using official Eclipse Temurin JRE
FROM eclipse-temurin:17-jre
WORKDIR /app

COPY --from=build /build/target/spring-java.jar ./spring-java.jar

EXPOSE 8080

CMD ["java", "-jar", "spring-java.jar"]