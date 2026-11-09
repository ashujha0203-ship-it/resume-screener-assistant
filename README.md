# Resume Screener Assistant

A learning project that will analyze a resume against a job description and show an advisory assessment. The current phase contains only the initial backend, Flutter Web placeholder, and local PostgreSQL setup.

## Technology stack

- Flutter Web and Dart
- Java 25 and Spring Boot 3.5.6
- Maven 3.10.0
- PostgreSQL 17 with Docker Compose

## Prerequisites

- JDK 25
- Maven 3.10.0
- Flutter SDK with web support and Chrome
- Docker Desktop with Docker Compose

On Windows, confirm the installed versions with:

```powershell
java -version
mvn -version
flutter --version
docker compose version
```

The Maven output should report Java 25.

## Local setup

From the project root, copy the example environment file and edit the local PostgreSQL password:

```powershell
Copy-Item .env.example .env
notepad .env
```

Start PostgreSQL when needed:

```powershell
docker compose up -d postgres
```

The database port is bound to `127.0.0.1`, so it is available only from the local machine.

PostgreSQL uses host port `5432` by default. If that port is already occupied, change `POSTGRES_PORT` in your local `.env` file to `55432`:

```dotenv
POSTGRES_PORT=55432
```

Docker Compose uses this value to publish the container port, and Spring Boot uses it to connect to PostgreSQL. Keep the same `POSTGRES_PORT` value in the environment used for both commands. For example, after loading `.env` as shown below, run `docker compose up -d postgres` and the backend from that same PowerShell session.

Before running Maven, load the same settings from `.env` into the current PowerShell process:

```powershell
Get-Content .env | Where-Object { $_ -match '^[A-Za-z_][A-Za-z0-9_]*=' } | ForEach-Object {
    $name, $value = $_ -split '=', 2
    Set-Item -Path "Env:$name" -Value $value
}
```

This keeps the local password out of tracked files and makes it available to Spring Boot.

The OpenAI API key is optional for starting the backend. To enable AI analysis in a later phase, set `OPENAI_API_KEY` in your local `.env` file. The key is read by the backend only; do not put it in Flutter configuration or source code. The example leaves it blank intentionally.

## Run the backend

In that same PowerShell terminal, from the project root:

```powershell
Set-Location backend
mvn clean verify
mvn spring-boot:run
```

Flyway applies versioned schema migrations at startup. Hibernate is configured to validate the schema and does not create or update tables.

The backend runs at `http://localhost:8080`. Verify its health endpoint in another terminal:

```powershell
Invoke-RestMethod http://localhost:8080/api/health
```

The response is `{"status":"UP"}`.

## Run Flutter Web

In a separate PowerShell terminal:

```powershell
Set-Location frontend
flutter analyze
flutter run -d chrome
```

This phase provides only a placeholder page. OpenAI analysis and analysis/history REST APIs will be added in later phases.
