# Resume Screener Assistant

A learning and software-engineering assessment project that compares a resume with a job description and presents an advisory assessment. The application consists of a Flutter Web frontend, a Java 25/Spring Boot REST API, PostgreSQL persistence, Flyway migrations, and a backend-only Google Gemini API integration using an OpenAI-compatible Chat Completions endpoint.

The score and generated content support human review. They are not an automatic hiring decision.

## Problem and objectives

Reviewing a resume against a role can be time-consuming. This application demonstrates an end-to-end workflow for submitting a resume and job description, receiving a structured assessment, saving selected results, and reviewing previous analyses.

Project objectives:

- Keep UI, REST API, business logic, persistence, and provider integration in separate, understandable layers.
- Validate inputs and AI responses before saving generated results.
- Keep provider credentials on the backend.
- Avoid persisting the raw resume and job description in the analysis entity.
- Make the score advisory and keep a human in the decision-making loop.

## Features

- Submit a job description and resume, with an optional candidate name.
- Receive a match score from 0 to 100.
- See exactly five matching skills, three skill gaps, and three suggested interview questions.
- See an assessment breakdown across four criteria:
  - **Required skills (40%)** — evidence of skills required by the role.
  - **Relevant experience (30%)** — relevance of the candidate's experience.
  - **Seniority and scope (20%)** — alignment with the role's level and scope.
  - **Nice-to-have skills and domain relevance (10%)** — evidence for preferred skills and relevant domain knowledge.
- Review results and the advisory notice in the Results screen.
- Search saved analyses by candidate-name substring and filter by inclusive score range in History.
- Open a saved analysis to view its candidate name, score, timestamp, matching skills, skill gaps, and interview questions.

The saved-analysis detail response does not include the individual criterion ratings or rationales; those are returned with the original analysis response but are not stored in the `analysis_results` entity.

## Technology stack

| Area | Technology |
|---|---|
| Frontend | Flutter Web, Dart |
| Backend | Java 25, Spring Boot 3.5.6, Maven |
| Database | PostgreSQL 17 |
| Schema management | Flyway |
| AI integration | Google Gemini API using an OpenAI-compatible Chat Completions endpoint |
| Local database | Docker Compose |
| Backend containerization | Docker |

## Architecture and request flow

1. The Flutter screens submit user input through the frontend controller and `AnalysisApiService`.
2. The Spring `AnalysisController` validates the request through the service layer.
3. The backend sends the job description and resume to the configured Google Gemini API endpoint using backend configuration and credentials.
4. The backend validates the structured response and computes the weighted score.
5. It saves the candidate name, score, matching skills, skill gaps, interview questions, and creation timestamp in PostgreSQL.
6. The Flutter app displays the immediate result and can retrieve saved analyses through the history and detail endpoints.

The browser does not receive or use the Gemini API key. CORS is centrally configured for explicitly listed origins.

## Project structure

```text
resumeAssistant/
├── backend/
│   ├── src/main/java/com/example/resumescreener/
│   │   ├── config/       # Provider configuration and CORS
│   │   ├── controller/   # Health and analysis REST endpoints
│   │   ├── dto/          # API and validated analysis data types
│   │   ├── entity/       # JPA persistence model
│   │   ├── exception/    # Safe API exception mapping
│   │   ├── repository/   # Spring Data persistence
│   │   └── service/      # Validation, scoring, history, AI integration
│   ├── src/main/resources/
│   │   ├── application.yml
│   │   └── db/migration/ # Flyway SQL migrations
│   ├── src/test/java/    # Unit, MVC, and PostgreSQL integration tests
│   └── Dockerfile
├── frontend/
│   ├── lib/
│   │   ├── app/          # App setup and shared controller
│   │   ├── config/       # API base URL configuration
│   │   ├── models/
│   │   ├── screens/      # Analyze, Results, History, saved-analysis detail
│   │   ├── services/     # REST API client
│   │   └── widgets/      # App shell and navigation
│   └── test/             # Model, service, controller, screen, widget tests
├── docker-compose.yml
├── .env.example
├── AI_USAGE.md
└── DEMO.md
```

## Prerequisites

- JDK 25.
- Maven (the project has been verified with Maven 3.10.0).
- Flutter SDK with Dart and Flutter Web support.
- Google Chrome for `flutter run -d chrome`.
- Docker Desktop with Docker Compose.
- Gemini API key for successful live AI analysis.

Check the installed tools from PowerShell:

```powershell
java -version
mvn -version
flutter --version
docker compose version
```

The Maven output should report Java 25. The backend POM targets Java 25.

## Environment configuration

Copy `.env.example` to an untracked local `.env` at the project root and edit the local values. Do not commit `.env`, put credentials in source code, or pass the Gemini API key to Flutter.

```powershell
Set-Location 'C:\path\to\resumeAssistant'
Copy-Item .env.example .env
notepad .env
```

The environment variables are:

| Variable | Purpose | Default/configuration |
|---|---|---|
| `POSTGRES_HOST` | Backend database host | `127.0.0.1` |
| `POSTGRES_DB` | Database name used by Compose and Spring | `resume_screener` |
| `POSTGRES_USER` | Database user | `resume_screener` |
| `POSTGRES_PASSWORD` | Database password | Set locally; required by Compose |
| `POSTGRES_PORT` | Host port published by Compose and used by Spring | `5432` |
| `POSTGRES_SSL_MODE` | PostgreSQL SSL connection mode | `prefer` |
| `CORS_ALLOWED_ORIGINS` | Comma-separated explicit browser origins | `http://localhost:5000` |
| `GEMINI_API_KEY` | Google Gemini API credential used by the backend | Blank in `.env.example`; required for live analysis |
| `GEMINI_MODEL` | Gemini model used for analysis | `gemini-3.5-flash-lite` |
| `GEMINI_ENDPOINT` | Gemini OpenAI-compatible API endpoint | Configured in `application.yml` |
| `GEMINI_CONNECT_TIMEOUT` | Provider connection timeout | `5s` |
| `GEMINI_READ_TIMEOUT` | Provider read timeout | `30s` |

`GEMINI_API_KEY` is backend-only. If it is not configured, the backend can still start and serve other endpoints, but analysis requests receive a safe `503 AI_NOT_CONFIGURED` response.

CORS defaults to `http://localhost:5000`, matching the Flutter command below. For another frontend origin, configure `CORS_ALLOWED_ORIGINS` with one or more comma-separated, specific origins.

The API CORS policy allows GET, POST, and OPTIONS with Content-Type and Accept headers; credentials are disabled.

For hosted PostgreSQL providers such as Neon, configure the database host, port, name, user, password, and SSL mode using the provider's connection details. Use `POSTGRES_SSL_MODE=require` when the database provider requires SSL.

## Database setup

From the project root, start the Compose PostgreSQL service:

```powershell
docker compose up -d postgres
docker compose ps
```

Compose binds the database to `127.0.0.1` and stores its files in the named `postgres_data` volume. The volume persists across ordinary container restarts.

Do not use volume-removal commands such as `docker compose down -v` if you want to retain local data.

At backend startup, Flyway applies versioned SQL migrations from `backend/src/main/resources/db/migration`. Hibernate uses schema validation (`ddl-auto: validate`); it does not create or update the schema.

Keep the database name, user, password, and host port consistent between Compose and the backend environment. If the default host port is occupied, choose a free `POSTGRES_PORT` in `.env`; do not change a database's existing password to solve a port conflict.

## Start the backend

In a PowerShell terminal, load the local `.env` values into that process and start Spring Boot:

```powershell
Set-Location 'C:\path\to\resumeAssistant'

Get-Content .env |
    Where-Object { $_ -match '^[A-Za-z_][A-Za-z0-9_]*=' } |
    ForEach-Object {
        $name, $value = $_ -split '=', 2
        Set-Item -Path "Env:$name" -Value $value
    }

Set-Location .\backend
mvn spring-boot:run
```

The backend listens at `http://localhost:8080` by default.

From another PowerShell terminal, check health:

```powershell
Invoke-RestMethod 'http://localhost:8080/api/health'
```

The successful response contains `status: UP`.

## Start Flutter Web

In a separate PowerShell terminal:

```powershell
Set-Location 'C:\path\to\resumeAssistant\frontend'

flutter run -d chrome --web-port 5000 --dart-define=API_BASE_URL=http://localhost:8080
```

Open `http://localhost:5000` in the browser.

`API_BASE_URL` is a compile-time Flutter define and defaults to `http://localhost:8080`; it must point to the backend, not directly to the Gemini API.

## REST API reference

All endpoints are served by the backend at `http://localhost:8080`. Error responses use an object containing `timestamp`, `status`, `code`, and a safe `message`.

### `GET /api/health`

Returns the backend health status. A successful response contains a `status` field set to `UP`.

### `POST /api/analyses`

Creates and saves an analysis. Send JSON with:

| Field | Requirement |
|---|---|
| `candidateName` | Optional; maximum 200 characters when supplied |
| `jobDescription` | Required, nonblank; maximum 20,000 characters |
| `resume` | Required, nonblank; maximum 30,000 characters |

On success, returns **201 Created** and the analysis `id`, `createdAt`, candidate name, match score, the four criterion ratings and rationales, five matching skills, three skill gaps, three interview questions, and advisory notice.

The raw resume and job description are not part of the response or persisted entity.

Relevant errors:

- **400 Bad Request** — invalid input or malformed JSON (`INVALID_REQUEST`).
- **405 Method Not Allowed** — unsupported method.
- **415 Unsupported Media Type** — unsupported request media type.
- **502 Bad Gateway** — unusable provider response or provider failure.
- **503 Service Unavailable** — AI not configured (`AI_NOT_CONFIGURED`) or provider rate limited.
- **504 Gateway Timeout** — provider timeout.
- **500 Internal Server Error** — unexpected server error.

### `GET /api/analyses`

Returns a page of saved analysis records.

Optional query parameters:

| Parameter | Constraint |
|---|---|
| `candidateName` | Nonblank when supplied, maximum 200 characters; case-insensitive substring match |
| `minScore` | Inclusive integer from 0 to 100 |
| `maxScore` | Inclusive integer from 0 to 100 |
| `page` | Zero-based integer, default `0`, must be zero or greater |
| `size` | Default `20`, must be from 1 to 100 |

When both score bounds are supplied, `minScore` must not exceed `maxScore`.

Results are sorted by creation time descending, then ID descending.

The response contains `content`, `page`, `size`, `totalElements`, and `totalPages`. Each content item includes the saved detail fields described below.

Relevant errors: **400 Bad Request** (`INVALID_REQUEST`) for invalid filters or pagination, **405 Method Not Allowed**, and **500 Internal Server Error** for unexpected failures.

### `GET /api/analyses/{id}`

Retrieves one saved analysis by UUID.

The response includes `id`, `createdAt`, `candidateName`, `matchScore`, `matchingSkills`, `skillGaps`, and `interviewQuestions`.

It does not include the original resume, job description, or criterion rationales.

Relevant errors:

- **400 Bad Request** (`INVALID_REQUEST`) — malformed UUID.
- **404 Not Found** (`ANALYSIS_NOT_FOUND`) — no record exists for that UUID.
- **405 Method Not Allowed** or **500 Internal Server Error** — unsupported method or unexpected server failure.

## Docker backend

The backend includes a Dockerfile that builds the Spring Boot application and runs it using a Java 25 runtime.

Build the image from the project root:

```powershell
docker build -t resume-screener-backend:local ./backend
```

The container listens on port `8080`.

For hosted deployment, provide the required database and Gemini configuration through the hosting platform's environment-variable settings. Do not place production credentials in the Dockerfile or source control.

## Tests and checks

### Backend verification

Run backend verification from `backend`:

```powershell
mvn clean verify
```

The backend integration tests require a reachable PostgreSQL database configured with the `POSTGRES_*` environment values. They write test analysis rows; use a local development/test database, not production data.

The Gemini configuration property tests expect `GEMINI_API_KEY` to be absent in the Maven test process for the unconfigured-key case.

To preserve database variables while ensuring the Gemini key is unset, run this in a dedicated PowerShell test terminal from the project root:

```powershell
Get-Content .env |
    Where-Object { $_ -match '^[A-Za-z_][A-Za-z0-9_]*=' } |
    ForEach-Object {
        $name, $value = $_ -split '=', 2

        if ($name -in @(
            'POSTGRES_HOST',
            'POSTGRES_DB',
            'POSTGRES_USER',
            'POSTGRES_PASSWORD',
            'POSTGRES_PORT',
            'POSTGRES_SSL_MODE'
        )) {
            Set-Item -Path "Env:$name" -Value $value
        }
    }

Remove-Item Env:GEMINI_API_KEY -ErrorAction SilentlyContinue

Set-Location .\backend
mvn clean verify
```

Do not import a blank `GEMINI_API_KEY` from `.env` into this Maven test process. In a separate backend-startup terminal, load `.env` as shown above if you need the configured key for live analysis.

### Flutter verification

Run Flutter checks from `frontend`:

```powershell
flutter analyze
flutter test
```

Flutter tests use mocked HTTP clients for API and widget/controller behavior. Backend integration tests exercise Spring MVC and PostgreSQL while mocking the Gemini client; these are not browser-based end-to-end tests.

## Privacy and security summary

- The Gemini API key is configured on the backend and is not included in Flutter configuration.
- Resume and job-description text are sent to Google Gemini for analysis. Review Google's applicable data-use and retention policies before submitting sensitive information.
- The application's `analysis_results` entity stores the optional candidate name, score, generated skills/gaps/questions, and creation time. It does not have fields for the raw resume or job description.
- Resumes and job descriptions are treated as untrusted input in the AI instructions. This is a mitigation, not a guarantee against every prompt-injection attempt.
- The prompt requests assessment of job-relevant evidence and excludes protected or irrelevant personal characteristics. This does not guarantee unbiased output.
- The score is advisory decision-support information and must not be used as an automatic hiring decision.

See [AI_USAGE.md](./AI_USAGE.md) for a fuller description of implemented AI behavior and limitations.

## Verification status and known limitations

The backend and frontend automated checks have passed in the local development environment:

- Backend: 106 tests passed.
- Flutter: 130 tests passed.
- Flutter analysis: no issues found.
- Docker backend image: built successfully and tested locally.
- Backend health endpoint: returned `UP`.
- PostgreSQL connection and Flyway schema validation: successful.

Successful live AI analysis, populated history, live filtering against saved records, and saved-analysis detail retrieval have not all been verified through the live browser workflow. Automated tests do not replace those manual checks.

See [DEMO.md](./DEMO.md) for a cautious demonstration sequence and screenshot checklist.