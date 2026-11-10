# AI Usage Disclosure

## Purpose

The application uses an AI model to compare a supplied resume with a job description and generate job-relevant evidence, matching skills, skill gaps, and suggested interview questions. The resulting match score is decision-support information only.

## Data flow and API key

The Flutter app sends the candidate name (optional), job description, and resume to the Spring Boot backend. The backend sends the job description and resume to the OpenAI Responses API. The OpenAI API key is read by the backend from `OPENAI_API_KEY`; it is not sent to or configured in the Flutter Web app.

The backend model and request timeouts are configurable through `OPENAI_MODEL`, `OPENAI_CONNECT_TIMEOUT`, and `OPENAI_READ_TIMEOUT`. The defaults are `gpt-4o-mini`, five seconds for connection, and 30 seconds for reading the response.

## Structured output and validation

The backend requests strict JSON Schema output from the Responses API. The expected structured response contains four criterion assessments, each with a rating and rationale, plus lists of matching skills, skill gaps, and interview questions.

Before saving a result, backend validation requires:

- All four criterion assessments and a nonblank rationale for each.
- A rating from 0 through 100 for each criterion.
- Exactly five nonblank matching skills.
- Exactly three nonblank skill gaps.
- Exactly three nonblank interview questions.

Malformed, refused, or unusable provider responses are mapped to safe API errors rather than saved as successful analyses.

## Match score

The backend computes an integer score using the validated criterion ratings:

```text
required skills                                  × 40%
relevant experience                              × 30%
seniority and scope                              × 20%
nice-to-have skills and domain relevance         × 10%
```

The weighted result is rounded to an integer using `HALF_UP`. The four category ratings and rationales are returned with the initial analysis response. They are not persisted in the saved `analysis_results` entity and are therefore not part of the saved-detail response.

## Untrusted content and prompt-injection handling

The backend labels the job description and resume as untrusted data and supplies system instructions telling the model to ignore embedded commands, requests, role changes, or prompt injections. It also instructs the model to assess job-relevant evidence and not to evaluate protected or irrelevant personal characteristics.

These are prompt-level mitigations. They do not guarantee prevention of every prompt-injection attack or ensure fair outcomes.

## Privacy and retention

- The raw resume and job description are sent to the AI provider to perform the requested analysis.
- The Responses API request sets `store` to `false`. This request setting is not a promise of zero provider retention, and this document makes no claims about provider retention beyond the implemented setting.
- The application's `analysis_results` entity does not contain raw resume or job-description fields. It saves the optional candidate name, generated match score, matching skills, skill gaps, interview questions, and creation timestamp.
- The application has no documented deletion or expiration behavior for saved analyses in this implementation.
- Do not submit real personal data unless you have the appropriate authorization and have reviewed the applicable provider and organizational data-handling requirements.

## Limitations and human oversight

AI-generated analysis can be incomplete or inaccurate. A numerical score may not reflect context that is important to a hiring process. The application does not make an automatic hiring recommendation; the result is advisory only.

A qualified human must review the source materials and generated assessment before using it. The prompt's instruction to avoid protected or irrelevant personal characteristics is not a guarantee that output will be unbiased, lawful, or suitable for a hiring decision.

## AI usage disclosure

This project uses the OpenAI Responses API to generate structured resume-to-job-description assessments. User-provided resume and job-description text is sent to the provider for processing. Generated analysis is validated by the backend, scored using a fixed weighted formula, and partially saved as described above. No successful live OpenAI analysis has yet been verified for the current demo environment.
