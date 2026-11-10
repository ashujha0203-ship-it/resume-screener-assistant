package com.example.resumescreener.service;

import java.net.SocketTimeoutException;
import java.net.UnknownHostException;
import java.nio.charset.StandardCharsets;
import javax.net.ssl.SSLHandshakeException;

import com.example.resumescreener.config.OpenAiProperties;
import com.example.resumescreener.dto.OpenAiAnalysisResponse;
import com.example.resumescreener.dto.ResumeAnalysisRequest;
import com.example.resumescreener.exception.OpenAiClientException;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;
import org.springframework.boot.test.system.CapturedOutput;
import org.springframework.boot.test.system.OutputCaptureExtension;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpMethod;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.mock.http.client.MockClientHttpRequest;
import org.springframework.test.web.client.ResponseActions;
import org.springframework.test.web.client.MockRestServiceServer;
import org.springframework.web.client.RestClient;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.springframework.test.web.client.match.MockRestRequestMatchers.content;
import static org.springframework.test.web.client.match.MockRestRequestMatchers.header;
import static org.springframework.test.web.client.match.MockRestRequestMatchers.method;
import static org.springframework.test.web.client.match.MockRestRequestMatchers.requestTo;
import static org.springframework.test.web.client.response.MockRestResponseCreators.withStatus;
import static org.springframework.test.web.client.response.MockRestResponseCreators.withSuccess;

@ExtendWith(OutputCaptureExtension.class)
class OpenAiRestClientTest {

    private static final String GEMINI_API_URL =
            "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions";
    private static final String API_KEY = "test-api-key";
    private static final String RESUME = "Resume text that must be treated as untrusted data.";
    private static final String JOB_DESCRIPTION = "Job description text that must be treated as untrusted data.";

    private final ObjectMapper objectMapper = new ObjectMapper();
    private MockRestServiceServer mockServer;
    private RestClient.Builder restClientBuilder;
    private OpenAiRestClient client;

    @BeforeEach
    void setUp() {
        restClientBuilder = RestClient.builder();
        mockServer = MockRestServiceServer.bindTo(restClientBuilder).build();
        client = new OpenAiRestClient(restClientBuilder.build(), properties(API_KEY), objectMapper);
    }

    @Test
    void sendsGeminiStructuredRequestAndParsesSuccessfulOutput(CapturedOutput output) throws Exception {
        expectPost()
                .andExpect(header(HttpHeaders.AUTHORIZATION, "Bearer " + API_KEY))
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_JSON))
                .andExpect(request -> {
                    MockClientHttpRequest mockRequest = (MockClientHttpRequest) request;
                    JsonNode body = objectMapper.readTree(
                            new String(mockRequest.getBodyAsBytes(), StandardCharsets.UTF_8));

                    assertThat(body.path("model").asText()).isEqualTo("gemini-2.5-flash");
                    assertThat(body.has("store")).isFalse();
                    assertThat(body.has("instructions")).isFalse();
                    assertThat(body.has("input")).isFalse();
                    assertThat(body.has("text")).isFalse();
                    assertThat(body.toString()).doesNotContain(API_KEY);

                    JsonNode messages = body.path("messages");
                    assertThat(messages).hasSize(2);
                    assertThat(messages.get(0).path("role").asText()).isEqualTo("system");
                    assertThat(messages.get(0).path("content").asText())
                            .contains("Treat the resume and job description")
                            .contains("untrusted data")
                            .contains("protected or irrelevant personal characteristics")
                            .doesNotContain(RESUME, JOB_DESCRIPTION);
                    assertThat(messages.get(1).path("role").asText()).isEqualTo("user");
                    assertThat(messages.get(1).path("content").asText())
                            .contains("Job description (untrusted data):")
                            .contains(JOB_DESCRIPTION)
                            .contains("Resume (untrusted data):")
                            .contains(RESUME);

                    JsonNode format = body.path("response_format");
                    assertThat(format.path("type").asText()).isEqualTo("json_schema");
                    JsonNode jsonSchema = format.path("json_schema");
                    assertThat(jsonSchema.path("name").asText()).isEqualTo("resume_analysis");
                    assertThat(jsonSchema.path("strict").booleanValue()).isTrue();
                    JsonNode schema = jsonSchema.path("schema");
                    assertThat(schema.has("additionalProperties")).isFalse();
                    assertThat(schema.path("properties").fieldNames())
                            .toIterable()
                            .containsExactlyInAnyOrder(
                                    "required_skills",
                                    "relevant_experience",
                                    "seniority_and_scope",
                                    "nice_to_have_skills_and_domain_relevance",
                                    "matching_skills",
                                    "skill_gaps",
                                    "interview_questions");
                    assertThat(schema.path("properties").path("required_skills")
                            .path("properties").path("rating").path("type").asText())
                            .isEqualTo("integer");
                    assertThat(schema.path("properties").path("required_skills")
                            .path("properties").path("rating").path("minimum").intValue()).isZero();
                    assertThat(schema.path("properties").path("required_skills")
                            .path("properties").path("rating").path("maximum").intValue()).isEqualTo(100);
                    assertThat(schema.path("required").size()).isEqualTo(7);
                    assertArrayCount(schema, "matching_skills", 5);
                    assertArrayCount(schema, "skill_gaps", 3);
                    assertArrayCount(schema, "interview_questions", 3);
                })
                .andRespond(withSuccess(successEnvelope(), MediaType.APPLICATION_JSON));

        OpenAiAnalysisResponse response = client.analyze(request());

        assertThat(response.requiredSkills().rating()).isEqualTo(90);
        assertThat(response.requiredSkills().rationale()).isEqualTo("Core requirements are demonstrated.");
        assertThat(response.relevantExperience().rating()).isEqualTo(80);
        assertThat(response.seniorityAndScope().rating()).isEqualTo(70);
        assertThat(response.niceToHaveSkillsAndDomainRelevance().rating()).isEqualTo(60);
        assertThat(response.matchingSkills()).hasSize(5);
        assertThat(response.skillGaps()).hasSize(3);
        assertThat(response.interviewQuestions()).hasSize(3);
        assertThat(output.getAll()).doesNotContain(API_KEY);
        mockServer.verify();
    }

    @Test
    void usesConfiguredEndpoint() throws Exception {
        String configuredEndpoint = "https://example.test/v1/chat/completions";
        OpenAiProperties properties = properties(API_KEY);
        properties.setEndpoint(configuredEndpoint);
        client = new OpenAiRestClient(restClientBuilder.build(), properties, objectMapper);
        mockServer.expect(requestTo(configuredEndpoint))
                .andExpect(method(HttpMethod.POST))
                .andRespond(withSuccess(successEnvelope(), MediaType.APPLICATION_JSON));

        assertThat(client.analyze(request()).matchingSkills()).hasSize(5);
        mockServer.verify();
    }

    @Test
    void rejectsMalformedStructuredJsonWithoutRetry() throws Exception {
        expectPost().andRespond(withSuccess(responseEnvelope("not JSON"), MediaType.APPLICATION_JSON));

        assertThatThrownBy(() -> client.analyze(request()))
                .isInstanceOf(OpenAiClientException.class)
                .satisfies(exception -> {
                    OpenAiClientException clientException = (OpenAiClientException) exception;
                    assertThat(clientException.getFailure()).isEqualTo(OpenAiClientException.Failure.INVALID_RESPONSE);
                    assertThat(clientException.getDiagnosticCategory())
                            .isEqualTo(OpenAiClientException.DiagnosticCategory.RESPONSE_PARSING_FAILURE);
                    assertThat(clientException.getRetryAttempt()).isEqualTo(1);
                    assertThat(clientException.getCause()).isInstanceOf(JsonProcessingException.class);
                })
                .hasMessage("Gemini returned an incomplete or invalid structured response.");
        mockServer.verify();
    }

    @Test
    void doesNotRetryTlsFailure() {
        expectPost().andRespond(org.springframework.test.web.client.response.MockRestResponseCreators
                .withException(new SSLHandshakeException("sensitive TLS detail")));

        assertThatThrownBy(() -> client.analyze(request()))
                .isInstanceOf(OpenAiClientException.class)
                .satisfies(exception -> {
                    OpenAiClientException clientException = (OpenAiClientException) exception;
                    assertThat(clientException.getFailure()).isEqualTo(OpenAiClientException.Failure.TRANSPORT);
                    assertThat(clientException.getDiagnosticCategory())
                            .isEqualTo(OpenAiClientException.DiagnosticCategory.TRANSPORT_FAILURE);
                    assertThat(clientException.getRetryAttempt()).isEqualTo(1);
                    assertThat(clientException.getCause())
                            .isInstanceOf(org.springframework.web.client.ResourceAccessException.class);
                })
                .hasMessage("Gemini request failed because of a network or transport error.")
                .hasMessageNotContaining("sensitive TLS detail")
                .hasMessageNotContaining(API_KEY);
        mockServer.verify();
    }

    @Test
    void rejectsMissingOutputWithoutRetry() {
        expectPost().andRespond(withSuccess("{\"choices\":[]}", MediaType.APPLICATION_JSON));

        assertThatThrownBy(() -> client.analyze(request()))
                .isInstanceOf(OpenAiClientException.class)
                .satisfies(exception -> {
                    OpenAiClientException clientException = (OpenAiClientException) exception;
                    assertThat(clientException.getFailure()).isEqualTo(OpenAiClientException.Failure.INVALID_RESPONSE);
                    assertThat(clientException.getDiagnosticCategory())
                            .isEqualTo(OpenAiClientException.DiagnosticCategory.INVALID_PROVIDER_RESPONSE);
                    assertThat(clientException.getRetryAttempt()).isEqualTo(1);
                });
        mockServer.verify();
    }

    @Test
    void rejectsMissingChoicesWithoutRetry() {
        expectPost().andRespond(withSuccess("{\"unexpected\":[]}", MediaType.APPLICATION_JSON));

        assertInvalidProviderResponse();
        mockServer.verify();
    }

    @Test
    void rejectsMissingMessageContentWithoutRetry() {
        expectPost().andRespond(withSuccess(
                "{\"choices\":[{\"finish_reason\":\"stop\",\"message\":{\"role\":\"assistant\"}}]}",
                MediaType.APPLICATION_JSON));

        assertInvalidProviderResponse();
        mockServer.verify();
    }

    @Test
    void rejectsEmptyMessageContentWithoutRetry() {
        expectPost().andRespond(withSuccess(
                "{\"choices\":[{\"finish_reason\":\"stop\",\"message\":{\"content\":\" \"}}]}",
                MediaType.APPLICATION_JSON));

        assertInvalidProviderResponse();
        mockServer.verify();
    }

    @Test
    void rejectsIncompleteResponseWithoutRetry() {
        String incomplete = """
                {"choices":[{"finish_reason":"length","message":{"role":"assistant","content":"{}"}}]}
                """;
        expectPost().andRespond(withSuccess(incomplete, MediaType.APPLICATION_JSON));

        assertThatThrownBy(() -> client.analyze(request()))
                .isInstanceOf(OpenAiClientException.class)
                .satisfies(exception -> assertThat(((OpenAiClientException) exception).getFailure())
                        .isEqualTo(OpenAiClientException.Failure.INVALID_RESPONSE))
                .hasMessage("Gemini returned an incomplete or invalid structured response.");
        mockServer.verify();
    }

    @Test
    void handlesProviderRefusalWithoutRetry() {
        String refusal = """
                {"choices":[{"finish_reason":"stop","message":{
                  "role":"assistant","content":null,"refusal":"sensitive provider refusal text"
                }}]}
                """;
        expectPost().andRespond(withSuccess(refusal, MediaType.APPLICATION_JSON));

        assertThatThrownBy(() -> client.analyze(request()))
                .isInstanceOf(OpenAiClientException.class)
                .satisfies(exception -> {
                    OpenAiClientException clientException = (OpenAiClientException) exception;
                    assertThat(clientException.getFailure()).isEqualTo(OpenAiClientException.Failure.REFUSAL);
                    assertThat(clientException.getDiagnosticCategory())
                            .isEqualTo(OpenAiClientException.DiagnosticCategory.PROVIDER_REFUSAL);
                    assertThat(clientException.getRetryAttempt()).isEqualTo(1);
                })
                .hasMessage("Gemini refused to generate a resume analysis.")
                .hasMessageNotContaining("sensitive provider refusal text");
        mockServer.verify();
    }

    @Test
    void handlesBlockedFinishReasonAsRefusal() {
        String blocked = """
                {"choices":[{"finish_reason":"SAFETY","message":{"content":""}}]}
                """;
        expectPost().andRespond(withSuccess(blocked, MediaType.APPLICATION_JSON));

        assertThatThrownBy(() -> client.analyze(request()))
                .isInstanceOf(OpenAiClientException.class)
                .satisfies(exception -> assertThat(((OpenAiClientException) exception).getFailure())
                        .isEqualTo(OpenAiClientException.Failure.REFUSAL))
                .hasMessage("Gemini refused to generate a resume analysis.");
        mockServer.verify();
    }

    @ParameterizedTest
    @CsvSource({
        "401, AUTHENTICATION",
        "403, AUTHENTICATION",
        "404, CLIENT_ERROR",
        "400, CLIENT_ERROR"
    })
    void doesNotRetryAuthenticationOrOtherClientErrors(int status, OpenAiClientException.Failure failure) {
        expectPost().andRespond(withStatus(HttpStatus.valueOf(status))
                .contentType(MediaType.APPLICATION_JSON)
                .body("{\"error\":\"sensitive provider response\"}"));

        assertThatThrownBy(() -> client.analyze(request()))
                .isInstanceOf(OpenAiClientException.class)
                .satisfies(exception -> {
                    OpenAiClientException clientException = (OpenAiClientException) exception;
                    assertThat(clientException.getFailure()).isEqualTo(failure);
                    assertThat(clientException.getHttpStatus()).isEqualTo(status);
                    assertThat(clientException.getDiagnosticCategory())
                            .isEqualTo(OpenAiClientException.DiagnosticCategory.HTTP_CLIENT_ERROR);
                    assertThat(clientException.getRetryAttempt()).isEqualTo(1);
                })
                .hasMessageNotContaining("sensitive provider response")
                .hasMessageNotContaining(API_KEY);
        mockServer.verify();
    }

    @Test
    void extractsOnlyRecognizedProviderErrorFields() {
        expectPost().andRespond(withStatus(HttpStatus.BAD_REQUEST)
                .contentType(MediaType.APPLICATION_JSON)
                .body("""
                        {"error":{"code":503,"status":"UNAVAILABLE","message":"private details"}}
                        """));

        assertProviderErrorMetadata("503", "UNAVAILABLE");
        mockServer.verify();
    }

    @Test
    void leavesMissingProviderErrorFieldsUnset() {
        expectPost().andRespond(withStatus(HttpStatus.BAD_REQUEST)
                .contentType(MediaType.APPLICATION_JSON)
                .body("{\"error\":{\"message\":\"must not be retained\"}}"));

        assertProviderErrorMetadata(null, null);
        mockServer.verify();
    }

    @Test
    void ignoresMalformedProviderErrorJson() {
        expectPost().andRespond(withStatus(HttpStatus.BAD_REQUEST)
                .contentType(MediaType.APPLICATION_JSON)
                .body("{\"error\":{\"code\":\"UNAVAILABLE\""));

        assertProviderErrorMetadata(null, null);
        mockServer.verify();
    }

    @Test
    void rejectsOversizedProviderErrorFieldsIndependently() {
        String oversizedCode = "A".repeat(65);
        expectPost().andRespond(withStatus(HttpStatus.BAD_REQUEST)
                .contentType(MediaType.APPLICATION_JSON)
                .body("{\"error\":{\"code\":\"" + oversizedCode + "\",\"status\":\"UNAVAILABLE\"}}"));

        assertProviderErrorMetadata(null, "UNAVAILABLE");
        mockServer.verify();
    }

    @Test
    void ignoresUnexpectedProviderErrorJsonStructures() {
        expectPost().andRespond(withStatus(HttpStatus.BAD_REQUEST)
                .contentType(MediaType.APPLICATION_JSON)
                .body("""
                        {"code":"TOP_LEVEL_CODE","status":"TOP_LEVEL_STATUS","error":"private text"}
                        """));

        assertProviderErrorMetadata(null, null);
        mockServer.verify();
    }

    @ParameterizedTest
    @CsvSource({
        "408, TIMEOUT",
        "501, SERVER_ERROR",
        "505, SERVER_ERROR",
        "422, CLIENT_ERROR"
    })
    void doesNotRetryNonEligibleHttpStatuses(int status, OpenAiClientException.Failure failure) {
        expectPost().andRespond(withStatus(HttpStatus.valueOf(status))
                .contentType(MediaType.APPLICATION_JSON)
                .body("{\"error\":\"sensitive provider response\"}"));

        assertThatThrownBy(() -> client.analyze(request()))
                .isInstanceOf(OpenAiClientException.class)
                .satisfies(exception -> {
                    OpenAiClientException clientException = (OpenAiClientException) exception;
                    assertThat(clientException.getFailure()).isEqualTo(failure);
                    assertThat(clientException.getHttpStatus()).isEqualTo(status);
                    assertThat(clientException.getDiagnosticCategory()).isEqualTo(
                            status >= 500
                                    ? OpenAiClientException.DiagnosticCategory.HTTP_SERVER_ERROR
                                    : OpenAiClientException.DiagnosticCategory.HTTP_CLIENT_ERROR);
                    assertThat(clientException.getRetryAttempt()).isEqualTo(1);
                })
                .hasMessageNotContaining("sensitive provider response")
                .hasMessageNotContaining(API_KEY);
        mockServer.verify();
    }

    @ParameterizedTest
    @CsvSource({"500", "502", "504"})
    void retriesOnlyTheRemainingEligibleServerStatuses(int status) throws Exception {
        expectPost().andRespond(withStatus(HttpStatus.valueOf(status)));
        expectPost().andRespond(withSuccess(successEnvelope(), MediaType.APPLICATION_JSON));

        assertThat(client.analyze(request()).matchingSkills()).hasSize(5);
        mockServer.verify();
    }

    @Test
    void doesNotRetryRateLimitOrQuotaResponses() {
        expectPost().andRespond(withStatus(HttpStatus.TOO_MANY_REQUESTS)
                .contentType(MediaType.APPLICATION_JSON)
                .body("{\"error\":\"sensitive provider response\"}"));

        assertThatThrownBy(() -> client.analyze(request()))
                .isInstanceOf(OpenAiClientException.class)
                .satisfies(exception -> {
                    OpenAiClientException clientException = (OpenAiClientException) exception;
                    assertThat(clientException.getFailure()).isEqualTo(OpenAiClientException.Failure.RATE_LIMITED);
                    assertThat(clientException.getHttpStatus()).isEqualTo(429);
                    assertThat(clientException.getDiagnosticCategory())
                            .isEqualTo(OpenAiClientException.DiagnosticCategory.HTTP_CLIENT_ERROR);
                    assertThat(clientException.getRetryAttempt()).isEqualTo(1);
                })
                .hasMessageNotContaining("sensitive provider response");
        mockServer.verify();
    }

    @Test
    void retriesTransientServerFailureOnceAndReturnsSuccessfulResponse() throws Exception {
        expectPost().andRespond(withStatus(HttpStatus.SERVICE_UNAVAILABLE)
                .contentType(MediaType.APPLICATION_JSON)
                .body("{\"error\":\"sensitive provider response\"}"));
        expectPost().andRespond(withSuccess(successEnvelope(), MediaType.APPLICATION_JSON));

        assertThat(client.analyze(request()).skillGaps()).hasSize(3);
        mockServer.verify();
    }

    @Test
    void retriesEligibleTransientFailureAtMostOnce() {
        expectPost().andRespond(withStatus(HttpStatus.SERVICE_UNAVAILABLE));
        expectPost().andRespond(withStatus(HttpStatus.SERVICE_UNAVAILABLE));

        assertThatThrownBy(() -> client.analyze(request()))
                .isInstanceOf(OpenAiClientException.class)
                .satisfies(exception -> {
                    OpenAiClientException clientException = (OpenAiClientException) exception;
                    assertThat(clientException.getFailure()).isEqualTo(OpenAiClientException.Failure.SERVER_ERROR);
                    assertThat(clientException.getHttpStatus()).isEqualTo(503);
                    assertThat(clientException.getDiagnosticCategory())
                            .isEqualTo(OpenAiClientException.DiagnosticCategory.HTTP_SERVER_ERROR);
                    assertThat(clientException.getRetryAttempt()).isEqualTo(2);
                });
        mockServer.verify();
    }

    @Test
    void retriesConnectionOrReadTimeoutOnce() throws Exception {
        expectPost().andRespond(org.springframework.test.web.client.response.MockRestResponseCreators
                .withException(new SocketTimeoutException("sensitive timeout detail")));
        expectPost().andRespond(withSuccess(successEnvelope(), MediaType.APPLICATION_JSON));

        assertThat(client.analyze(request()).interviewQuestions()).hasSize(3);
        mockServer.verify();
    }

    @Test
    void doesNotRetryDnsFailure() {
        expectPost().andRespond(org.springframework.test.web.client.response.MockRestResponseCreators
                .withException(new UnknownHostException("sensitive host detail")));

        assertThatThrownBy(() -> client.analyze(request()))
                .isInstanceOf(OpenAiClientException.class)
                .satisfies(exception -> {
                    OpenAiClientException clientException = (OpenAiClientException) exception;
                    assertThat(clientException.getFailure()).isEqualTo(OpenAiClientException.Failure.TRANSPORT);
                    assertThat(clientException.getDiagnosticCategory())
                            .isEqualTo(OpenAiClientException.DiagnosticCategory.TRANSPORT_FAILURE);
                    assertThat(clientException.getRetryAttempt()).isEqualTo(1);
                    assertThat(clientException.getCause())
                            .isInstanceOf(org.springframework.web.client.ResourceAccessException.class);
                })
                .hasMessage("Gemini request failed because of a network or transport error.")
                .hasMessageNotContaining("sensitive host detail")
                .hasMessageNotContaining(API_KEY);
        mockServer.verify();
    }

    @Test
    void retriesTimeoutAtMostOnceThenReturnsSanitizedTimeoutError() {
        expectPost().andRespond(org.springframework.test.web.client.response.MockRestResponseCreators
                .withException(new SocketTimeoutException("sensitive timeout detail")));
        expectPost().andRespond(org.springframework.test.web.client.response.MockRestResponseCreators
                .withException(new SocketTimeoutException("sensitive timeout detail")));

        assertThatThrownBy(() -> client.analyze(request()))
                .isInstanceOf(OpenAiClientException.class)
                .satisfies(exception -> {
                    OpenAiClientException clientException = (OpenAiClientException) exception;
                    assertThat(clientException.getFailure()).isEqualTo(OpenAiClientException.Failure.TIMEOUT);
                    assertThat(clientException.getDiagnosticCategory())
                            .isEqualTo(OpenAiClientException.DiagnosticCategory.TRANSPORT_FAILURE);
                    assertThat(clientException.getRetryAttempt()).isEqualTo(2);
                    assertThat(clientException.getCause())
                            .isInstanceOf(org.springframework.web.client.ResourceAccessException.class);
                })
                .hasMessage("Gemini request timed out.")
                .hasMessageNotContaining("sensitive timeout detail")
                .hasMessageNotContaining(API_KEY);
        mockServer.verify();
    }

    @Test
    void reportsMissingApiKeyWithoutMakingARequest() {
        client = new OpenAiRestClient(RestClient.builder().build(), properties(" "), new ObjectMapper());

        assertThatThrownBy(() -> client.analyze(request()))
                .isInstanceOf(OpenAiClientException.class)
                .satisfies(exception -> assertThat(((OpenAiClientException) exception).getFailure())
                        .isEqualTo(OpenAiClientException.Failure.CONFIGURATION))
                .hasMessage("Gemini analysis is not configured. Set GEMINI_API_KEY in the backend environment.");
        mockServer.verify();
    }

    @Test
    void parsesProviderShapeWithoutApplyingBusinessValidation() throws Exception {
        String invalidOutput = """
                {
                  "required_skills":{"rating":101,"rationale":"reason"},
                  "relevant_experience":{"rating":80,"rationale":"reason"},
                  "seniority_and_scope":{"rating":70,"rationale":"reason"},
                  "nice_to_have_skills_and_domain_relevance":{"rating":60,"rationale":"reason"},
                  "matching_skills":["one"],
                  "skill_gaps":["one","two","three"],
                  "interview_questions":["one","two","three"]
                }
                """;
        expectPost().andRespond(withSuccess(responseEnvelope(invalidOutput), MediaType.APPLICATION_JSON));

        OpenAiAnalysisResponse response = client.analyze(request());

        assertThat(response.requiredSkills().rating()).isEqualTo(101);
        assertThat(response.matchingSkills()).containsExactly("one");
        mockServer.verify();
    }

    @Test
    void rejectsUnknownPropertiesInStructuredOutput() throws Exception {
        String outputWithUnknownProperty = """
                {
                  "required_skills":{"rating":90,"rationale":"reason"},
                  "relevant_experience":{"rating":80,"rationale":"reason"},
                  "seniority_and_scope":{"rating":70,"rationale":"reason"},
                  "nice_to_have_skills_and_domain_relevance":{"rating":60,"rationale":"reason"},
                  "matching_skills":["one","two","three","four","five"],
                  "skill_gaps":["one","two","three"],
                  "interview_questions":["one","two","three"],
                  "unexpected":"not allowed"
                }
                """;
        expectPost().andRespond(
                withSuccess(responseEnvelope(outputWithUnknownProperty), MediaType.APPLICATION_JSON));

        assertThatThrownBy(() -> client.analyze(request()))
                .isInstanceOf(OpenAiClientException.class)
                .satisfies(exception -> {
                    OpenAiClientException clientException = (OpenAiClientException) exception;
                    assertThat(clientException.getFailure()).isEqualTo(OpenAiClientException.Failure.INVALID_RESPONSE);
                    assertThat(clientException.getDiagnosticCategory())
                            .isEqualTo(OpenAiClientException.DiagnosticCategory.RESPONSE_PARSING_FAILURE);
                    assertThat(clientException.getRetryAttempt()).isEqualTo(1);
                    assertThat(clientException.getCause()).isInstanceOf(JsonProcessingException.class);
                });
        mockServer.verify();
    }

    private void assertInvalidProviderResponse() {
        assertThatThrownBy(() -> client.analyze(request()))
                .isInstanceOf(OpenAiClientException.class)
                .satisfies(exception -> {
                    OpenAiClientException clientException = (OpenAiClientException) exception;
                    assertThat(clientException.getFailure()).isEqualTo(OpenAiClientException.Failure.INVALID_RESPONSE);
                    assertThat(clientException.getDiagnosticCategory())
                            .isEqualTo(OpenAiClientException.DiagnosticCategory.INVALID_PROVIDER_RESPONSE);
                    assertThat(clientException.getRetryAttempt()).isEqualTo(1);
                })
                .hasMessage("Gemini returned an incomplete or invalid structured response.");
    }

    private void assertProviderErrorMetadata(String expectedCode, String expectedStatus) {
        assertThatThrownBy(() -> client.analyze(request()))
                .isInstanceOf(OpenAiClientException.class)
                .satisfies(exception -> {
                    OpenAiClientException clientException = (OpenAiClientException) exception;
                    assertThat(clientException.getProviderErrorCode()).isEqualTo(expectedCode);
                    assertThat(clientException.getProviderErrorStatus()).isEqualTo(expectedStatus);
                    assertThat(clientException.getMessage())
                            .doesNotContain("private details")
                            .doesNotContain("must not be retained")
                            .doesNotContain("TOP_LEVEL");
                    assertThat(clientException.getCause()).isNull();
                });
    }

    private ResponseActions expectPost() {
        return mockServer.expect(requestTo(GEMINI_API_URL))
                .andExpect(method(HttpMethod.POST));
    }

    private void assertArrayCount(JsonNode schema, String field, int count) {
        JsonNode arraySchema = schema.path("properties").path(field);
        assertThat(arraySchema.path("type").asText()).isEqualTo("array");
        assertThat(arraySchema.path("items").path("type").asText()).isEqualTo("string");
        assertThat(arraySchema.path("minItems").intValue()).isEqualTo(count);
        assertThat(arraySchema.path("maxItems").intValue()).isEqualTo(count);
    }

    private ResumeAnalysisRequest request() {
        return new ResumeAnalysisRequest("Optional candidate", JOB_DESCRIPTION, RESUME);
    }

    private OpenAiProperties properties(String apiKey) {
        OpenAiProperties properties = new OpenAiProperties();
        properties.setApiKey(apiKey);
        properties.setModel("gemini-2.5-flash");
        return properties;
    }

    private String successEnvelope() throws Exception {
        return responseEnvelope("""
                {
                  "required_skills":{"rating":90,"rationale":"Core requirements are demonstrated."},
                  "relevant_experience":{"rating":80,"rationale":"Relevant experience is present."},
                  "seniority_and_scope":{"rating":70,"rationale":"Scope aligns with the role."},
                  "nice_to_have_skills_and_domain_relevance":{"rating":60,"rationale":"Some preferred experience is present."},
                  "matching_skills":["Java","Spring Boot","PostgreSQL","REST APIs","Maven"],
                  "skill_gaps":["Docker","Cloud deployment","Automated testing"],
                  "interview_questions":["Question one?","Question two?","Question three?"]
                }
                """);
    }

    private String responseEnvelope(String structuredText) throws Exception {
        String escapedText = objectMapper.writeValueAsString(structuredText);
        return """
                {"choices":[{"finish_reason":"stop","message":{"role":"assistant","content":%s}}]}
                """.formatted(escapedText);
    }
}
