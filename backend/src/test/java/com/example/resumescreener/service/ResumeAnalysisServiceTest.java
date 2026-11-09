package com.example.resumescreener.service;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

import com.example.resumescreener.dto.AnalysisResultResponse;
import com.example.resumescreener.dto.OpenAiAnalysisResponse;
import com.example.resumescreener.dto.OpenAiAnalysisResponse.CriterionRating;
import com.example.resumescreener.dto.ResumeAnalysisRequest;
import com.example.resumescreener.entity.AnalysisResult;
import com.example.resumescreener.exception.InvalidAnalysisInputException;
import com.example.resumescreener.exception.InvalidAnalysisResponseException;
import com.example.resumescreener.exception.OpenAiClientException;
import com.example.resumescreener.repository.AnalysisResultRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class ResumeAnalysisServiceTest {

    @Mock
    private OpenAiAnalysisClient openAiAnalysisClient;

    @Mock
    private AnalysisResultRepository analysisResultRepository;

    @Mock
    private AnalysisResult persistedEntity;

    private ResumeAnalysisService service;

    @BeforeEach
    void setUp() {
        service = new ResumeAnalysisService(
                new AnalysisInputValidator(),
                openAiAnalysisClient,
                new AnalysisResponseValidator(),
                new AnalysisScoringService(),
                analysisResultRepository);
    }

    @Test
    void validatesAnalyzesScoresPersistsAndReturnsCompleteAnalysis() {
        ResumeAnalysisRequest request =
                new ResumeAnalysisRequest("Jordan Lee", "Backend engineer role", "Resume text");
        OpenAiAnalysisResponse providerResponse = validProviderResponse();
        UUID persistedId = UUID.randomUUID();
        Instant persistedAt = Instant.parse("2026-01-02T03:04:05Z");

        when(openAiAnalysisClient.analyze(request)).thenReturn(providerResponse);
        when(analysisResultRepository.save(any(AnalysisResult.class))).thenReturn(persistedEntity);
        when(persistedEntity.getId()).thenReturn(persistedId);
        when(persistedEntity.getCreatedAt()).thenReturn(persistedAt);

        AnalysisResultResponse response = service.analyze(request);

        ArgumentCaptor<AnalysisResult> entityCaptor = ArgumentCaptor.forClass(AnalysisResult.class);
        verify(analysisResultRepository).save(entityCaptor.capture());
        AnalysisResult savedEntity = entityCaptor.getValue();
        assertThat(savedEntity.getCandidateName()).isEqualTo("Jordan Lee");
        assertThat(savedEntity.getMatchScore()).isEqualTo(70);
        assertThat(savedEntity.getMatchingSkills())
                .containsExactly("Java", "Spring", "SQL", "REST", "Testing");
        assertThat(savedEntity.getSkillGaps()).containsExactly("Cloud", "Docker", "Kubernetes");
        assertThat(savedEntity.getInterviewQuestions()).containsExactly(
                "Question one?", "Question two?", "Question three?");

        assertThat(response.id()).isEqualTo(persistedId);
        assertThat(response.createdAt()).isEqualTo(persistedAt);
        assertThat(response.candidateName()).isEqualTo("Jordan Lee");
        assertThat(response.matchScore()).isEqualTo(70);
        assertThat(response.requiredSkills().rating()).isEqualTo(80);
        assertThat(response.requiredSkills().rationale()).isEqualTo("Required skills evidence.");
        assertThat(response.relevantExperience().rating()).isEqualTo(70);
        assertThat(response.seniorityAndScope().rating()).isEqualTo(60);
        assertThat(response.niceToHaveSkillsAndDomainRelevance().rating()).isEqualTo(50);
        assertThat(response.matchingSkills()).containsExactly("Java", "Spring", "SQL", "REST", "Testing");
        assertThat(response.skillGaps()).containsExactly("Cloud", "Docker", "Kubernetes");
        assertThat(response.interviewQuestions())
                .containsExactly("Question one?", "Question two?", "Question three?");
        assertThat(response.advisoryNotice()).contains("not an automatic hiring decision");
        assertThatThrownBy(() -> response.matchingSkills().add("New skill"))
                .isInstanceOf(UnsupportedOperationException.class);
        verify(openAiAnalysisClient).analyze(request);
    }

    @Test
    void rejectsInvalidInputBeforeCallingProviderOrSaving() {
        ResumeAnalysisRequest request = new ResumeAnalysisRequest(null, " ", "Resume text");

        assertThatThrownBy(() -> service.analyze(request))
                .isInstanceOf(InvalidAnalysisInputException.class);

        verifyNoInteractions(openAiAnalysisClient, analysisResultRepository);
    }

    @Test
    void doesNotSaveWhenProviderFails() {
        ResumeAnalysisRequest request =
                new ResumeAnalysisRequest(null, "Backend engineer role", "Resume text");
        when(openAiAnalysisClient.analyze(request)).thenThrow(
                new OpenAiClientException(
                        OpenAiClientException.Failure.SERVER_ERROR,
                        "OpenAI request failed."));

        assertThatThrownBy(() -> service.analyze(request))
                .isInstanceOf(OpenAiClientException.class)
                .hasMessage("OpenAI request failed.");

        verify(analysisResultRepository, never()).save(any());
    }

    @Test
    void doesNotSaveWhenProviderResponseIsInvalid() {
        ResumeAnalysisRequest request =
                new ResumeAnalysisRequest(null, "Backend engineer role", "Resume text");
        OpenAiAnalysisResponse validResponse = validProviderResponse();
        when(openAiAnalysisClient.analyze(request)).thenReturn(
                new OpenAiAnalysisResponse(
                        null,
                        validResponse.relevantExperience(),
                        validResponse.seniorityAndScope(),
                        validResponse.niceToHaveSkillsAndDomainRelevance(),
                        validResponse.matchingSkills(),
                        validResponse.skillGaps(),
                        validResponse.interviewQuestions()));

        assertThatThrownBy(() -> service.analyze(request))
                .isInstanceOf(InvalidAnalysisResponseException.class)
                .hasMessageNotContaining("Resume text")
                .hasMessageNotContaining("Backend engineer role");

        verify(analysisResultRepository, never()).save(any());
    }

    @Test
    void propagatesPersistenceFailureInsteadOfReturningSuccess() {
        ResumeAnalysisRequest request =
                new ResumeAnalysisRequest(null, "Backend engineer role", "Resume text");
        when(openAiAnalysisClient.analyze(request)).thenReturn(validProviderResponse());
        when(analysisResultRepository.save(any())).thenThrow(new IllegalStateException("Database unavailable"));

        assertThatThrownBy(() -> service.analyze(request))
                .isInstanceOf(IllegalStateException.class)
                .hasMessage("Database unavailable");
    }

    private OpenAiAnalysisResponse validProviderResponse() {
        return new OpenAiAnalysisResponse(
                new CriterionRating(80, "Required skills evidence."),
                new CriterionRating(70, "Relevant experience evidence."),
                new CriterionRating(60, "Seniority and scope evidence."),
                new CriterionRating(50, "Nice-to-have skills and domain evidence."),
                List.of("Java", "Spring", "SQL", "REST", "Testing"),
                List.of("Cloud", "Docker", "Kubernetes"),
                List.of("Question one?", "Question two?", "Question three?"));
    }
}
