package com.example.resumescreener.controller;

import java.time.Instant;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.UUID;

import com.example.resumescreener.dto.OpenAiAnalysisResponse;
import com.example.resumescreener.dto.OpenAiAnalysisResponse.CriterionRating;
import com.example.resumescreener.dto.ResumeAnalysisRequest;
import com.example.resumescreener.service.OpenAiAnalysisClient;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
class AnalysisIntegrationTest {

    @MockitoBean
    private OpenAiAnalysisClient openAiAnalysisClient;

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @Test
    void createsPersistsAndRetrievesAnalysisWithoutPersistingRawInput() throws Exception {
        String unique = UUID.randomUUID().toString();
        String rawJobDescription = "RAW_JOB_DESCRIPTION_" + unique;
        String rawResume = "RAW_RESUME_" + unique;
        String candidateName = "Persisted Candidate " + unique;
        when(openAiAnalysisClient.analyze(any())).thenReturn(providerResponse(82));

        JsonNode created = createAnalysis(candidateName, rawJobDescription, rawResume);
        UUID id = UUID.fromString(created.get("id").asText());

        assertThat(created.get("matchScore").asInt()).isEqualTo(82);
        assertThat(created.has("resume")).isFalse();
        assertThat(created.has("jobDescription")).isFalse();
        String persistedRow = jdbcTemplate.queryForObject(
                "SELECT row_to_json(a)::text FROM analysis_results a WHERE id = ?",
                String.class,
                id);
        assertThat(persistedRow).contains(candidateName);
        assertThat(persistedRow).doesNotContain(rawJobDescription, rawResume);

        mockMvc.perform(get("/api/analyses/{id}", id))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").value(id.toString()))
                .andExpect(jsonPath("$.candidateName").value(candidateName))
                .andExpect(jsonPath("$.matchScore").value(82))
                .andExpect(jsonPath("$.matchingSkills.length()").value(5))
                .andExpect(jsonPath("$.skillGaps.length()").value(3))
                .andExpect(jsonPath("$.interviewQuestions.length()").value(3))
                .andExpect(jsonPath("$.requiredSkills").doesNotExist())
                .andExpect(jsonPath("$.resume").doesNotExist())
                .andExpect(jsonPath("$.jobDescription").doesNotExist());
    }

    @Test
    void filtersByCandidateAndInclusiveScoreRangeAndPreservesSortAcrossPages() throws Exception {
        String unique = UUID.randomUUID().toString();
        when(openAiAnalysisClient.analyze(any())).thenAnswer(invocation -> {
            ResumeAnalysisRequest request = invocation.getArgument(0);
            int score = request.candidateName().endsWith(" Entry")
                    ? 40
                    : request.candidateName().endsWith(" Senior")
                            ? 70
                            : request.candidateName().endsWith(" Below") ? 39 : 60;
            return providerResponse(score);
        });

        List<JsonNode> createdRecords = new ArrayList<>();
        createdRecords.add(createAnalysis(
                "Alex " + unique + " Entry",
                "Role " + unique,
                "Resume " + unique));
        createdRecords.add(createAnalysis(
                "Alex " + unique + " Senior",
                "Role " + unique,
                "Resume " + unique));
        createdRecords.add(createAnalysis(
                "Alex " + unique + " Below",
                "Role " + unique,
                "Resume " + unique));
        createdRecords.add(createAnalysis(
                "Taylor " + unique,
                "Role " + unique,
                "Resume " + unique));

        JsonNode allMatches = readPage(
                "aLeX " + unique,
                40,
                70,
                0,
                10);
        assertThat(allMatches.get("totalElements").asLong()).isEqualTo(2);
        assertThat(allMatches.get("content")).hasSize(2);

        createdRecords.sort(Comparator
                .comparing((JsonNode record) -> Instant.parse(record.get("createdAt").asText()))
                .reversed()
                .thenComparing(record -> record.get("id").asText(), Comparator.reverseOrder()));
        List<String> expectedOrder = createdRecords.stream()
                .filter(record -> record.get("matchScore").asInt() >= 40
                        && record.get("matchScore").asInt() <= 70
                        && record.get("candidateName").asText().toLowerCase().contains("alex " + unique))
                .map(record -> record.get("id").asText())
                .toList();
        assertThat(expectedOrder).hasSize(2);

        JsonNode firstPage = readPage("aLeX " + unique, 40, 70, 0, 1);
        JsonNode secondPage = readPage("aLeX " + unique, 40, 70, 1, 1);
        assertThat(firstPage.get("totalPages").asInt()).isEqualTo(2);
        assertThat(firstPage.get("content").get(0).get("id").asText())
                .isEqualTo(expectedOrder.get(0));
        assertThat(secondPage.get("content").get(0).get("id").asText())
                .isEqualTo(expectedOrder.get(1));
    }

    @Test
    void rejectsInvalidRequestMalformedJsonAndInvalidUuid() throws Exception {
        mockMvc.perform(post("/api/analyses")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsBytes(
                                new ResumeAnalysisRequest(null, " ", "Resume text"))))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("INVALID_REQUEST"))
                .andExpect(jsonPath("$.message").value("The request is invalid."));

        mockMvc.perform(post("/api/analyses")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("INVALID_REQUEST"));

        mockMvc.perform(get("/api/analyses/not-a-uuid"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("INVALID_REQUEST"));
    }

    @Test
    void returnsSanitizedNotFoundForMissingRecord() throws Exception {
        mockMvc.perform(get("/api/analyses/{id}", UUID.randomUUID()))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("ANALYSIS_NOT_FOUND"))
                .andExpect(jsonPath("$.message").value("Analysis not found."));
    }

    @Test
    void mapsUnavailableTimeoutAndProviderFailuresToSafeResponses() throws Exception {
        when(openAiAnalysisClient.analyze(any()))
                .thenThrow(new com.example.resumescreener.exception.OpenAiClientException(
                        com.example.resumescreener.exception.OpenAiClientException.Failure.CONFIGURATION,
                        "Sensitive provider configuration."))
                .thenThrow(new com.example.resumescreener.exception.OpenAiClientException(
                        com.example.resumescreener.exception.OpenAiClientException.Failure.TIMEOUT,
                        "Sensitive provider timeout."))
                .thenThrow(new com.example.resumescreener.exception.OpenAiClientException(
                        com.example.resumescreener.exception.OpenAiClientException.Failure.SERVER_ERROR,
                        "Sensitive provider failure."));

        assertProviderError(503, "AI_NOT_CONFIGURED", "temporarily unavailable because");
        assertProviderError(504, "AI_TIMEOUT", "did not respond in time");
        assertProviderError(502, "AI_PROVIDER_ERROR", "could not complete the request");
    }

    private JsonNode createAnalysis(String candidateName, String jobDescription, String resume)
            throws Exception {
        ResumeAnalysisRequest request = new ResumeAnalysisRequest(
                candidateName,
                jobDescription,
                resume);
        MvcResult result = mockMvc.perform(post("/api/analyses")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsBytes(request)))
                .andExpect(status().isCreated())
                .andReturn();
        return objectMapper.readTree(result.getResponse().getContentAsByteArray());
    }

    private JsonNode readPage(
            String candidateName,
            int minScore,
            int maxScore,
            int page,
            int size) throws Exception {
        MvcResult result = mockMvc.perform(get("/api/analyses")
                        .param("candidateName", candidateName)
                        .param("minScore", Integer.toString(minScore))
                        .param("maxScore", Integer.toString(maxScore))
                        .param("page", Integer.toString(page))
                        .param("size", Integer.toString(size)))
                .andExpect(status().isOk())
                .andReturn();
        return objectMapper.readTree(result.getResponse().getContentAsByteArray());
    }

    private void assertProviderError(int statusCode, String code, String safeMessage)
            throws Exception {
        String body = objectMapper.writeValueAsString(
                new ResumeAnalysisRequest(null, "Role", "Resume"));
        MvcResult result = mockMvc.perform(post("/api/analyses")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(body))
                .andExpect(status().is(statusCode))
                .andExpect(jsonPath("$.code").value(code))
                .andExpect(jsonPath("$.message").value(
                        org.hamcrest.Matchers.containsString(safeMessage)))
                .andReturn();
        assertThat(result.getResponse().getContentAsString())
                .doesNotContain("Sensitive provider");
    }

    private OpenAiAnalysisResponse providerResponse(int score) {
        CriterionRating rating = new CriterionRating(score, "Evidence supports this rating.");
        return new OpenAiAnalysisResponse(
                rating,
                rating,
                rating,
                rating,
                List.of("Java", "Spring", "SQL", "REST", "Testing"),
                List.of("Cloud", "Leadership", "Domain"),
                List.of("Question one?", "Question two?", "Question three?"));
    }
}
