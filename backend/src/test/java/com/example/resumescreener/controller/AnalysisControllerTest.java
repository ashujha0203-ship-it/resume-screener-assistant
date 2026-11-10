package com.example.resumescreener.controller;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

import com.example.resumescreener.dto.AnalysisHistoryItemResponse;
import com.example.resumescreener.dto.AnalysisPageResponse;
import com.example.resumescreener.dto.AnalysisResultResponse;
import com.example.resumescreener.dto.CriterionAssessment;
import com.example.resumescreener.dto.ResumeAnalysisRequest;
import com.example.resumescreener.exception.AnalysisNotFoundException;
import com.example.resumescreener.exception.InvalidAnalysisInputException;
import com.example.resumescreener.exception.InvalidAnalysisResponseException;
import com.example.resumescreener.exception.InvalidAnalysisQueryException;
import com.example.resumescreener.exception.OpenAiClientException;
import com.example.resumescreener.service.AnalysisHistoryService;
import com.example.resumescreener.service.ResumeAnalysisService;
import org.junit.jupiter.api.extension.ExtendWith;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.http.MediaType;
import org.springframework.boot.test.system.CapturedOutput;
import org.springframework.boot.test.system.OutputCaptureExtension;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.context.bean.override.mockito.MockitoBean;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(AnalysisController.class)
@ExtendWith(OutputCaptureExtension.class)
class AnalysisControllerTest {

    @MockitoBean
    private ResumeAnalysisService resumeAnalysisService;

    @MockitoBean
    private AnalysisHistoryService analysisHistoryService;

    @Autowired
    private MockMvc mockMvc;

    @Test
    void createsAnalysisAndReturnsCreatedLocationAndFullBreakdown() throws Exception {
        UUID id = UUID.randomUUID();
        AnalysisResultResponse response = fullResponse(id);
        when(resumeAnalysisService.analyze(any(ResumeAnalysisRequest.class))).thenReturn(response);
        String requestBody = """
                {
                  "candidateName": "Jordan Lee",
                  "jobDescription": "Backend engineer role",
                  "resume": "Resume text"
                }
                """;

        mockMvc.perform(post("/api/analyses")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(requestBody))
                .andExpect(status().isCreated())
                .andExpect(header().string("Location", "http://localhost/api/analyses/" + id))
                .andExpect(jsonPath("$.id").value(id.toString()))
                .andExpect(jsonPath("$.matchScore").value(82))
                .andExpect(jsonPath("$.requiredSkills.rationale").value("Required skills evidence."))
                .andExpect(jsonPath("$.matchingSkills.length()").value(5))
                .andExpect(jsonPath("$.advisoryNotice").exists())
                .andExpect(jsonPath("$.resume").doesNotExist())
                .andExpect(jsonPath("$.jobDescription").doesNotExist());
        verify(resumeAnalysisService).analyze(new ResumeAnalysisRequest(
                "Jordan Lee", "Backend engineer role", "Resume text"));
    }

    @Test
    void returnsSanitizedBadRequestForInvalidAnalysisInput() throws Exception {
        when(resumeAnalysisService.analyze(any(ResumeAnalysisRequest.class)))
                .thenThrow(new InvalidAnalysisInputException("Resume content must never appear here."));

        mockMvc.perform(post("/api/analyses")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"candidateName":null,"jobDescription":"Job text","resume":"Secret resume"}
                                """))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("INVALID_REQUEST"))
                .andExpect(jsonPath("$.message").value("The request is invalid."))
                .andExpect(jsonPath("$.message").value(org.hamcrest.Matchers.not(
                        org.hamcrest.Matchers.containsString("Secret resume"))));
    }

    @Test
    void returnsBadRequestForMalformedBody() throws Exception {
        mockMvc.perform(post("/api/analyses")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("INVALID_REQUEST"));
    }

    @Test
    void returnsSanitizedMethodNotAllowedAndAllSupportedMethodsForCollectionEndpoint() throws Exception {
        mockMvc.perform(delete("/api/analyses"))
                .andExpect(status().isMethodNotAllowed())
                .andExpect(jsonPath("$.timestamp").exists())
                .andExpect(jsonPath("$.status").value(405))
                .andExpect(jsonPath("$.code").value("METHOD_NOT_ALLOWED"))
                .andExpect(jsonPath("$.message").value(
                        "The HTTP method is not supported for this endpoint."))
                .andExpect(header().string("Allow", org.hamcrest.Matchers.allOf(
                        org.hamcrest.Matchers.containsString("GET"),
                        org.hamcrest.Matchers.containsString("POST"))))
                .andExpect(content().string(org.hamcrest.Matchers.not(
                        org.hamcrest.Matchers.containsString("DELETE"))));
    }

    @Test
    void returnsOnlyGetAsAllowedMethodForDetailEndpoint() throws Exception {
        mockMvc.perform(delete("/api/analyses/{id}", UUID.randomUUID()))
                .andExpect(status().isMethodNotAllowed())
                .andExpect(header().string("Allow", "GET"));
    }

    @Test
    void returnsSanitizedUnsupportedMediaTypeForUnsupportedContentType() throws Exception {
        mockMvc.perform(post("/api/analyses")
                        .contentType(MediaType.APPLICATION_XML)
                        .content("<analysis/>"))
                .andExpect(status().isUnsupportedMediaType())
                .andExpect(jsonPath("$.timestamp").exists())
                .andExpect(jsonPath("$.status").value(415))
                .andExpect(jsonPath("$.code").value("UNSUPPORTED_MEDIA_TYPE"))
                .andExpect(jsonPath("$.message").value("The request media type is not supported."))
                .andExpect(content().string(org.hamcrest.Matchers.not(
                        org.hamcrest.Matchers.containsString("application/xml"))));
    }

    @Test
    void returnsSanitizedBadGatewayForInvalidProviderResponse() throws Exception {
        when(resumeAnalysisService.analyze(any(ResumeAnalysisRequest.class)))
                .thenThrow(new InvalidAnalysisResponseException("Sensitive provider response details."));

        mockMvc.perform(post("/api/analyses")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"candidateName":null,"jobDescription":"Job text","resume":"Resume text"}
                                """))
                .andExpect(status().isBadGateway())
                .andExpect(jsonPath("$.timestamp").exists())
                .andExpect(jsonPath("$.status").value(502))
                .andExpect(jsonPath("$.code").value("INVALID_PROVIDER_RESPONSE"))
                .andExpect(jsonPath("$.message").value(
                        "The analysis provider returned an unusable response."))
                .andExpect(content().string(org.hamcrest.Matchers.not(
                        org.hamcrest.Matchers.containsString("Sensitive provider response details."))));
    }

    @Test
    void returnsSanitizedGatewayTimeoutForProviderTimeout() throws Exception {
        when(resumeAnalysisService.analyze(any(ResumeAnalysisRequest.class)))
                .thenThrow(new OpenAiClientException(
                        OpenAiClientException.Failure.TIMEOUT,
                        "Sensitive provider timeout details."));

        mockMvc.perform(post("/api/analyses")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"candidateName":null,"jobDescription":"Job text","resume":"Resume text"}
                                """))
                .andExpect(status().isGatewayTimeout())
                .andExpect(jsonPath("$.timestamp").exists())
                .andExpect(jsonPath("$.status").value(504))
                .andExpect(jsonPath("$.code").value("AI_TIMEOUT"))
                .andExpect(jsonPath("$.message").value("The analysis provider did not respond in time."))
                .andExpect(content().string(org.hamcrest.Matchers.not(
                        org.hamcrest.Matchers.containsString("Sensitive provider timeout details."))));
    }

    @Test
    void returnsSanitizedInternalErrorForUnexpectedException() throws Exception {
        when(resumeAnalysisService.analyze(any(ResumeAnalysisRequest.class)))
                .thenThrow(new IllegalStateException("Sensitive internal exception details."));

        mockMvc.perform(post("/api/analyses")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"candidateName":null,"jobDescription":"Job text","resume":"Resume text"}
                                """))
                .andExpect(status().isInternalServerError())
                .andExpect(jsonPath("$.timestamp").exists())
                .andExpect(jsonPath("$.status").value(500))
                .andExpect(jsonPath("$.code").value("INTERNAL_ERROR"))
                .andExpect(jsonPath("$.message").value("An unexpected error occurred."))
                .andExpect(content().string(org.hamcrest.Matchers.not(
                        org.hamcrest.Matchers.containsString("Sensitive internal exception details."))));
    }

    @Test
    void returnsAppropriateStatusForUnconfiguredAiProvider() throws Exception {
        when(resumeAnalysisService.analyze(any(ResumeAnalysisRequest.class)))
                .thenThrow(new OpenAiClientException(
                        OpenAiClientException.Failure.CONFIGURATION,
                        "Internal provider configuration detail."));

        mockMvc.perform(post("/api/analyses")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"candidateName":null,"jobDescription":"Job text","resume":"Resume text"}
                                """))
                .andExpect(status().isServiceUnavailable())
                .andExpect(jsonPath("$.code").value("AI_NOT_CONFIGURED"))
                .andExpect(jsonPath("$.message").value(org.hamcrest.Matchers.not(
                        org.hamcrest.Matchers.containsString("Internal provider"))));
    }

    @Test
    void logsOnlySafeProviderDiagnosticsAndPreservesTheGenericApiError(CapturedOutput output) throws Exception {
        String sensitiveMarker = "secret-key-resume-job-provider-body";
        OpenAiClientException httpFailure = new OpenAiClientException(
                OpenAiClientException.Failure.CLIENT_ERROR,
                400,
                sensitiveMarker,
                OpenAiClientException.DiagnosticCategory.HTTP_CLIENT_ERROR,
                1,
                null);
        OpenAiClientException transportFailure = new OpenAiClientException(
                OpenAiClientException.Failure.TRANSPORT,
                null,
                sensitiveMarker,
                OpenAiClientException.DiagnosticCategory.TRANSPORT_FAILURE,
                2,
                new org.springframework.web.client.ResourceAccessException(sensitiveMarker));
        when(resumeAnalysisService.analyze(any(ResumeAnalysisRequest.class)))
                .thenThrow(httpFailure)
                .thenThrow(transportFailure);

        for (int attempt = 0; attempt < 2; attempt++) {
            mockMvc.perform(post("/api/analyses")
                            .contentType(MediaType.APPLICATION_JSON)
                            .content("""
                                    {"candidateName":null,"jobDescription":"Synthetic job","resume":"Synthetic resume"}
                                    """))
                    .andExpect(status().isBadGateway())
                    .andExpect(jsonPath("$.status").value(502))
                    .andExpect(jsonPath("$.code").value("AI_PROVIDER_ERROR"))
                    .andExpect(jsonPath("$.message").value(
                            "The analysis provider could not complete the request."));
        }

        assertThat(output.getAll())
                .contains("category=HTTP_CLIENT_ERROR")
                .contains("httpStatus=400")
                .contains("retryAttempt=1")
                .contains("category=TRANSPORT_FAILURE")
                .contains("retryAttempt=2")
                .contains("causeClass=ResourceAccessException")
                .doesNotContain(sensitiveMarker)
                .doesNotContain("Authorization");
    }

    @Test
    void passesOptionalHistoryFiltersAndPaginationToService() throws Exception {
        AnalysisPageResponse response = new AnalysisPageResponse(List.of(), 2, 5, 0, 0);
        when(analysisHistoryService.search("Jordan", 40, 90, 2, 5)).thenReturn(response);

        mockMvc.perform(get("/api/analyses")
                        .param("candidateName", "Jordan")
                        .param("minScore", "40")
                        .param("maxScore", "90")
                        .param("page", "2")
                        .param("size", "5"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.page").value(2))
                .andExpect(jsonPath("$.size").value(5))
                .andExpect(jsonPath("$.totalElements").value(0));
        verify(analysisHistoryService).search("Jordan", 40, 90, 2, 5);
    }

    @Test
    void usesDefaultHistoryPagination() throws Exception {
        when(analysisHistoryService.search(null, null, null, 0, 20))
                .thenReturn(new AnalysisPageResponse(List.of(), 0, 20, 0, 0));

        mockMvc.perform(get("/api/analyses"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.page").value(0))
                .andExpect(jsonPath("$.size").value(20));
        verify(analysisHistoryService).search(null, null, null, 0, 20);
    }

    @Test
    void returnsBadRequestForInvalidHistoryFiltersAndMalformedPaging() throws Exception {
        when(analysisHistoryService.search(null, 90, 40, 0, 20))
                .thenThrow(new InvalidAnalysisQueryException("Internal filter details."));

        mockMvc.perform(get("/api/analyses").param("minScore", "90").param("maxScore", "40"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message").value("The request is invalid."))
                .andExpect(jsonPath("$.message").value(org.hamcrest.Matchers.not(
                        org.hamcrest.Matchers.containsString("Internal filter"))));

        mockMvc.perform(get("/api/analyses").param("page", "not-a-number"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("INVALID_REQUEST"));
    }

    @Test
    void retrievesAnalysisByIdUsingPersistedFieldsOnly() throws Exception {
        UUID id = UUID.randomUUID();
        AnalysisHistoryItemResponse response = historyItem(id);
        when(analysisHistoryService.getById(id)).thenReturn(response);

        mockMvc.perform(get("/api/analyses/{id}", id))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").value(id.toString()))
                .andExpect(jsonPath("$.candidateName").value("Jordan Lee"))
                .andExpect(jsonPath("$.matchScore").value(82))
                .andExpect(jsonPath("$.requiredSkills").doesNotExist())
                .andExpect(jsonPath("$.resume").doesNotExist());
    }

    @Test
    void returnsNotFoundForMissingAnalysisAndBadRequestForMalformedUuid() throws Exception {
        UUID id = UUID.randomUUID();
        when(analysisHistoryService.getById(eq(id))).thenThrow(new AnalysisNotFoundException());

        mockMvc.perform(get("/api/analyses/{id}", id))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("ANALYSIS_NOT_FOUND"))
                .andExpect(jsonPath("$.message").value("Analysis not found."));

        mockMvc.perform(get("/api/analyses/not-a-uuid"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("INVALID_REQUEST"));
    }

    private AnalysisResultResponse fullResponse(UUID id) {
        return new AnalysisResultResponse(
                id,
                Instant.parse("2026-01-02T03:04:05Z"),
                "Jordan Lee",
                82,
                new CriterionAssessment(80, "Required skills evidence."),
                new CriterionAssessment(85, "Relevant experience evidence."),
                new CriterionAssessment(80, "Seniority and scope evidence."),
                new CriterionAssessment(85, "Domain evidence."),
                List.of("Java", "Spring", "SQL", "REST", "Testing"),
                List.of("Cloud", "Docker", "Kubernetes"),
                List.of("Question one?", "Question two?", "Question three?"),
                "This is advisory.");
    }

    private AnalysisHistoryItemResponse historyItem(UUID id) {
        return new AnalysisHistoryItemResponse(
                id,
                Instant.parse("2026-01-02T03:04:05Z"),
                "Jordan Lee",
                82,
                List.of("Java", "Spring", "SQL", "REST", "Testing"),
                List.of("Cloud", "Docker", "Kubernetes"),
                List.of("Question one?", "Question two?", "Question three?"));
    }
}
