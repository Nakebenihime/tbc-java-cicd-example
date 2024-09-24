# to be continuous... CI/CD pipeline for Java Project (Spring Boot with Maven)
This repository is an example of a CI/CD pipeline for a Java project (Spring Boot with Maven) using to-be-continuous GitLab templates. (https://to-be-continuous.gitlab.io/doc/)

## Prerequisites
To get started, make sure you have the following tools installed:
- Docker
- Maven
- Gitlab Repository setup
- GitLab CI/CD setup

## Technology Stack

| Component                | Technology                                                                               |
|--------------------------|------------------------------------------------------------------------------------------|
| Docker template          | [GitLab Docker Template](https://gitlab.com/to-be-continuous/docker)                     |
| Gitleaks template        | [GitLab Gitleaks Template](https://gitlab.com/to-be-continuous/gitleaks)                 |
| Maven template           | [GitLab Maven Template](https://gitlab.com/to-be-continuous/maven)                       |
| Semantic-release template| [GitLab Semantic-release Template](https://gitlab.com/to-be-continuous/semantic-release) |
| Bash template            | [GitLab Bash Template](https://gitlab.com/to-be-continuous/bash)                         |

## CI/CD Pipeline Stages

| Stage              | Job                  | Description                                                                                                       | Branch        | Tag |
|--------------------|----------------------|-------------------------------------------------------------------------------------------------------------------|---------------|-----|
| **.pre**           | semantic-release-info | Runs to retrieve semantic release information.                                                                    | develop, main |     |
| **build**          | bash-shellcheck       | Runs a static analysis of your shell using Shellcheck.                                                            | develop, main |     |
| **build**          | docker-hadolint       | Runs Hadolint, a Dockerfile linter, to ensure Dockerfile best practices.                                          | develop, main | X   |
| **build**          | mvn-build             | Runs Maven build commands to compile the project.                                                                 | develop, main | X   |
| **test**           | gitleaks              | Runs Gitleaks to scan the repository for any secrets.                                                             | develop, main | X   |
| **test**           | mvn-dependency-check  | Runs Maven dependency-check to identify any known vulnerabilities in project dependencies.                        | develop, main | X   |
| **test**           | mvn-no-snapshot-deps  | Runs to ensure that no snapshot dependencies are used.                                                            | develop, main | X   |
| **test**           | mvn-sbom              | Runs to generate a Software Bill of Materials (SBOM) of the Maven project.                                        | develop, main | X   |
| **test**           | mvn-sonar             | Runs SonarQube analysis for code quality checks.                                                                  | develop, main | X   |
| **package-build**  | docker-kaniko-build   | Runs Kaniko to build Docker images.                                                                               | develop, main | X   |
| **package-test**   | docker-trivy          | Run Trivy in standalone mode to perform a static vulnerability scan on your built image.                          | develop, main | X   |
| **package-test**   | docker-sbom           | Runs to generate a Software Bill of Materials (SBOM) of the Docker image.                                         | develop, main | X   |
| **publish**        | mvn-deploy-release    | Runs to deploy the Maven project as a release in the Package registry.                                            |               | X   |
| **publish**        | mvn-deploy-snapshot   | Runs to deploy the Maven project as a snapshot in the Package registry.                                           | develop, main | X   |
| **publish**        | semantic-release      | Runs semantic release to automatically determine and release a new version using semantic versioning conventions. | main          |     |
| **publish**        | docker-publish        | Runs to publish Docker images in the Container registry.                                                          | main          |     |

## Getting Started

1. Clone the application repository using the following command:
```sh
git clone https://gitlab.com/d3269/tbc-java-cicd-example
```
2. Branch and Tag Rules Definition:

| Branch/Tag Pattern | Type    | Allowed to Merge         | Allowed to Push and Merge | Allowed to create |
|--------------------|---------|--------------------------|---------------------------|-------------------|
| develop (default)  | Branch  | Maintainers              | No one                    |                   |
| main               | Branch  | Maintainers              | No one                    |                   |
| feat/*             | Branch  | Developers + Maintainers | Developers + Maintainers  |                   |
| `*.*.*`            | Tag     |                          |                           | Maintainers       |

3. Secret Definition:

| Variable              | Description                                                                                                                                           | Protected | Masked | Expanded | Type     |
|-----------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------|-----------|--------|----------|----------|
| `SONAR_TOKEN`         | SonarQube or Sonarcloud authentication token (see https://docs.sonarqube.org/latest/user-guide/user-token/)                                           |           | X      | X        | Secret   |
| `NVD_API_KEY`         | NVD API Key required for the Dependency-Check job to function properly (see: https://nvd.nist.gov/developers/request-an-api-key)                      | X         | X      | X        | Secret   |
| `GIT_USERNAME`        | Git username (if you wish to release using Git credentials) - Gitlab login or username                                                                | X         | X      | X        | Variable |
| `GIT_PASSWORD`        | Git password (if you wish to release using Git credentials) - Gitlab 'project access token' or 'personal access token' with `write_repository` scopes | X         | X      | X        | Secret   |
| `MAVEN_SETTINGS_FILE` | Maven settings file (`settings.xml`) used for configuring Maven settings (see https://docs.gitlab.com/ee/user/packages/maven_repository/)             | X         |        |          | File     |
| `GITLAB_TOKEN`        | GitLab 'project access token' or 'personal access token' with `api`, `read_repository`, and `write_repository` scopes                                 | X         | X      | X        | Secret   |

MAVEN_SETTINGS_FILE should look like this :
```xml
<settings xmlns="http://maven.apache.org/SETTINGS/1.1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
  xsi:schemaLocation="http://maven.apache.org/SETTINGS/1.1.0 http://maven.apache.org/xsd/settings-1.1.0.xsd">
  <servers>
    <server>
      <id>gitlab-maven</id>
      <configuration>
        <httpHeaders>
          <property>
            <name>Job-Token</name>
            <value>${CI_JOB_TOKEN}</value>
          </property>
        </httpHeaders>
      </configuration>
    </server>
  </servers>
</settings>
```
4 Project Definition : review these values to reflect your project settings
```xml
<repositories>
    <repository>
        <!-- <repository><id> should match the <server><id> value in MAVEN_SETTINGS_FILE  -->
        <id>gitlab-maven</id>
        <url>${CI_API_V4_URL}/projects/${CI_PROJECT_ID}/packages/maven</url>
    </repository>
</repositories>

<distributionManagement>
    <repository>
        <id>gitlab-maven</id>
        <url>${CI_API_V4_URL}/projects/${CI_PROJECT_ID}/packages/maven</url>
    </repository>
    <snapshotRepository>
        <id>gitlab-maven</id>
        <url>${CI_API_V4_URL}/projects/${CI_PROJECT_ID}/packages/maven</url>
    </snapshotRepository>
</distributionManagement>
```
```xml
<scm>
    <!-- replace xxx with the gitlab group ID -->
    <!-- replace yyy with the gitlab project name -->
    <connection>scm:git:https://gitlab.com/xxx/yyy.git</connection>
    <developerConnection>scm:git:https://gitlab.com/xxx/yyy.git</developerConnection>
</scm>
```

```xml
<!-- replace xxx with the sonarcloud or sonarqube projectKey -->
<!-- replace yyy with the sonarcloud or sonarqube organization -->
<properties>
    <sonar.projectKey>xxx_yyy</sonar.projectKey>
    <sonar.organization>xxx</sonar.organization>
</properties>
```

## Additional Notes
- Customize `.gitlab-ci.yml` to add or modify stages and jobs based on specific project requirements.
- Regularly review and update pipeline configurations to incorporate new features or security enhancements.