# Local Demo Guide

This guide describes a local development demonstration only. It does not describe a deployed environment.

## Prerequisites

- Java 25 and Maven.
- Flutter SDK with Dart, Flutter Web support, and Google Chrome.
- Docker Desktop with Docker Compose.
- A local `.env` copied from `.env.example`.
- An OpenAI API key configured in the backend environment for a successful AI analysis.

Never put database credentials or the OpenAI key in source code, screenshots, Flutter defines, or commands that will be shared.

## Local environment setup

From the project root, create the local environment file if it does not exist and edit it locally:

```powershell
Set-Location 'C:\path\to\resumeAssistant'
if (-not (Test-Path .env)) {
    Copy-Item .env.example .env
}
notepad .env
```

Set the database password for the local Compose service and, if testing successful live analysis, configure `OPENAI_API_KEY`. Keep the key backend-only. The default database host port is 5432; if the existing local database uses another port, set `POSTGRES_PORT` to that existing port. The backend and Compose must use the same database settings.

## Start PostgreSQL safely

Check the existing Compose service before starting it:

```powershell
docker compose ps
docker ps --format "{{.Names}} {{.Status}} {{.Ports}}"
```

If PostgreSQL is already running, use that database and its existing port and credentials. If it is not running and this project owns the database service, start it without deleting or resetting its database:

```powershell
docker compose up -d postgres
docker compose ps
```

Compose stores database files in the persistent `postgres_data` volume. Do not use `docker compose down -v`, remove the volume, or recreate an existing database as part of this demo. If a database container already exists outside this Compose project, do not start a second database or change its credentials; configure the backend to use the existing service.

## Start the backend

In a PowerShell terminal, load `.env` into the backend process and launch Spring Boot:

```powershell
Set-Location 'C:\path\to\resumeAssistant'
Get-Content .env | Where-Object { $_ -match '^[A-Za-z_][A-Za-z0-9_]*=' } | ForEach-Object {
    $name, $value = $_ -split '=', 2
    Set-Item -Path "Env:$name" -Value $value
}
Set-Location .\backend
mvn spring-boot:run
```

Replace the example project path with the actual local project root. Flyway applies migrations during backend startup; Hibernate validates the database schema.

## Verify backend health

In another PowerShell terminal:

```powershell
Invoke-RestMethod 'http://localhost:8080/api/health'
```

The expected healthy status is `UP`.

## Start Flutter Web

In a separate PowerShell terminal:

```powershell
Set-Location 'C:\path\to\resumeAssistant\frontend'
flutter run -d chrome --web-port 5000 --dart-define=API_BASE_URL=http://localhost:8080
```

Open the application at `http://localhost:5000`. The default CORS origin is configured for this port.

## Suggested demonstration sequence

1. Show the Analyze form and note that candidate name is optional.
2. If OpenAI is configured and authorized for demo use, enter fictional candidate data and submit it. Do not use real candidate information.
3. Review the score, four criterion assessments, five matching skills, three gaps, three interview questions, and advisory notice on Results.
4. Open History and show the saved analysis.
5. Search using the fictional candidate name and apply a score range.
6. Open the saved analysis and review its available detail fields.
7. Optionally demonstrate the safe AI-not-configured error when the backend has no key; the request should not create a saved analysis.

Do not claim steps 2–6 have passed in a live browser unless they have been run successfully in the current environment.

## Expected behavior and errors

- The backend can start without an OpenAI key, but analysis returns HTTP 503 with code `AI_NOT_CONFIGURED`.
- Invalid input returns a safe HTTP 400 error.
- A saved analysis detail request for an unknown valid UUID returns HTTP 404; an invalid UUID returns HTTP 400.
- Provider failures are mapped to sanitized API errors.
- The score is advisory and not an automatic hiring decision.

## Screenshot checklist

Capture genuine browser screenshots only:

- Analyze form with fictional or empty data.
- Successful Results after a live analysis is verified, showing the advisory notice.
- History with a saved fictional analysis and filters applied.
- Saved-analysis detail for that record.
- Optionally, the safe AI-not-configured error.

Do not fabricate application states or include API keys, database credentials, real resumes, or real candidate details in screenshots.

## Verification status

### Automated widget and frontend tests

Flutter widget/controller/service tests cover UI states, navigation, mocked analysis and history requests, filters, pagination, retries, and saved-detail selection. API interactions in these tests use mocked HTTP. They are not browser E2E tests and do not verify a real OpenAI request.

### Backend integration tests

Backend integration tests exercise Spring MVC, service behavior, and PostgreSQL persistence. They mock the OpenAI client, so they do not call the live provider or validate real model output.

### Manual environment checks already recorded

- PostgreSQL authentication succeeded.
- The backend started successfully.
- `GET /api/health` returned `UP`.
- Flutter Web launched on port 5000.
- The History API returned HTTP 200.
- With no OpenAI key, analysis returned HTTP 503 with `AI_NOT_CONFIGURED`.
- That failed analysis request did not create a database record.
- History had zero saved records during that test session.

These are recorded results from the prior environment check; the database may have changed since then.

### Not yet verified live

Successful live OpenAI analysis has not been tested because an OpenAI API key was unavailable during the prior check. Populated history, filtering against live saved records, and saved-analysis detail retrieval have also not been verified through the live browser workflow. Treat those steps as pending until manually exercised.
