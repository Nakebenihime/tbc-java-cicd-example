FROM maven:3.9.8-eclipse-temurin-17-alpine AS BUILDER
LABEL mantainer="mario-dacosta@hotmail.fr" \
      version="1.0.0" \
      description="Java to-be-continuous CI/CD template" \
      name="tbc-java-cicd-template"

WORKDIR /application

COPY pom.xml .
RUN mvn dependency:go-offline

COPY ./src ./src
RUN mvn clean package -DskipTests

FROM eclipse-temurin:17-jre-alpine AS RUNNER
COPY --from=BUILDER /application/target/*.jar /application/app.jar

RUN addgroup --system spring && adduser --system --ingroup spring spring
USER spring:spring

EXPOSE 8080
ENTRYPOINT ["java","-Djava.security.egd=file:/dev/./urandom","-jar","/application/app.jar"]