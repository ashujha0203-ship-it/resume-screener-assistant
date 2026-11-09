package com.example.resumescreener.repository;

import java.sql.Timestamp;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

import com.example.resumescreener.dto.AnalysisPageResponse;
import com.example.resumescreener.dto.AnalysisHistoryItemResponse;
import com.example.resumescreener.entity.AnalysisResult;
import com.example.resumescreener.service.AnalysisHistoryService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.jdbc.AutoConfigureTestDatabase;
import org.springframework.boot.test.autoconfigure.orm.jpa.DataJpaTest;
import org.springframework.boot.test.autoconfigure.orm.jpa.TestEntityManager;

import static org.assertj.core.api.Assertions.assertThat;

@DataJpaTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
class AnalysisResultRepositoryTest {

    @Autowired
    private AnalysisResultRepository repository;

    @Autowired
    private TestEntityManager entityManager;

    @Test
    void savesAndRetrievesAnalysisResult() {
        AnalysisResult result = new AnalysisResult(
                "Jordan Lee",
                82,
                List.of("Java", "Spring Boot", "PostgreSQL", "REST APIs", "Maven"),
                List.of("Docker", "Cloud deployment", "Automated testing"),
                List.of(
                        "How would you design a REST API?",
                        "How do you test a Spring service?",
                        "How have you used PostgreSQL indexes?"));
        UUID generatedId = result.getId();

        AnalysisResult saved = repository.saveAndFlush(result);
        entityManager.clear();

        AnalysisResult retrieved = repository.findById(generatedId).orElseThrow();

        assertThat(saved.getId()).isEqualTo(generatedId);
        assertThat(retrieved.getCandidateName()).isEqualTo("Jordan Lee");
        assertThat(retrieved.getMatchScore()).isEqualTo(82);
        assertThat(retrieved.getMatchingSkills()).containsExactlyElementsOf(result.getMatchingSkills());
        assertThat(retrieved.getSkillGaps()).containsExactlyElementsOf(result.getSkillGaps());
        assertThat(retrieved.getInterviewQuestions()).containsExactlyElementsOf(result.getInterviewQuestions());
        assertThat(retrieved.getCreatedAt()).isNotNull();
    }

    @Test
    void filtersCaseInsensitivelyByNameAndInclusiveScoreRangeWithStablePagination() {
        String uniqueSuffix = UUID.randomUUID().toString();
        String alexMorganName = "Alex Morgan " + uniqueSuffix;
        String alexandraMorganName = "Alexandra Morgan " + uniqueSuffix;
        AnalysisResult alexMorgan = analysis(alexMorganName, 40);
        AnalysisResult alexandraMorgan = analysis(alexandraMorganName, 70);
        AnalysisResult alexBeta = analysis("Alex Beta " + uniqueSuffix, 60);
        AnalysisResult taylor = analysis("Taylor " + uniqueSuffix, 80);
        repository.saveAll(List.of(alexMorgan, alexandraMorgan, alexBeta, taylor));
        repository.flush();

        setCreatedAt(alexMorgan, Instant.parse("2026-01-01T00:00:00Z"));
        setCreatedAt(alexandraMorgan, Instant.parse("2026-01-01T00:00:00Z"));
        setCreatedAt(alexBeta, Instant.parse("2026-01-02T00:00:00Z"));
        setCreatedAt(taylor, Instant.parse("2026-01-03T00:00:00Z"));
        entityManager.clear();

        AnalysisHistoryService service = new AnalysisHistoryService(repository);
        String candidateNameFilter = uniqueSuffix.toUpperCase();
        AnalysisPageResponse firstPage = service.search(candidateNameFilter, 40, 70, 0, 2);
        AnalysisPageResponse secondPage = service.search(candidateNameFilter, 40, 70, 1, 2);
        boolean alexMorganSortsFirst =
                comparePostgresUuid(alexMorgan.getId(), alexandraMorgan.getId()) > 0;

        assertThat(firstPage.content()).extracting(AnalysisHistoryItemResponse::candidateName)
                .containsExactly(
                        "Alex Beta " + uniqueSuffix,
                        alexMorganSortsFirst ? alexMorganName : alexandraMorganName);
        assertThat(firstPage.content()).extracting(AnalysisHistoryItemResponse::matchScore).containsExactly(
                60, alexMorganSortsFirst ? 40 : 70);
        assertThat(secondPage.content()).hasSize(1);
        assertThat(List.of(firstPage.totalElements(), secondPage.totalElements()))
                .containsExactly(3L, 3L);
        assertThat(firstPage.totalPages()).isEqualTo(2);
    }

    @Test
    void filtersLiteralLikeWildcardsInCandidateName() {
        String uniqueSuffix = UUID.randomUUID().toString();
        String literalWildcardCandidate = "Alex_Example " + uniqueSuffix;
        repository.saveAll(List.of(
                analysis(literalWildcardCandidate, 60),
                analysis("AlexXExample " + uniqueSuffix, 60)));
        repository.flush();

        AnalysisHistoryService service = new AnalysisHistoryService(repository);
        AnalysisPageResponse response = service.search("Alex_Example " + uniqueSuffix, null, null, 0, 20);

        assertThat(response.content())
                .extracting(AnalysisHistoryItemResponse::candidateName)
                .containsExactly(literalWildcardCandidate);
    }

    @Test
    void filtersLiteralPercentInCandidateName() {
        String uniqueSuffix = UUID.randomUUID().toString();
        String literalPercentCandidate = "Alex%Example " + uniqueSuffix;
        repository.saveAll(List.of(
                analysis(literalPercentCandidate, 60),
                analysis("AlexXExample " + uniqueSuffix, 60)));
        repository.flush();

        AnalysisHistoryService service = new AnalysisHistoryService(repository);
        AnalysisPageResponse response =
                service.search("Alex%Example " + uniqueSuffix, null, null, 0, 20);

        assertThat(response.content())
                .extracting(AnalysisHistoryItemResponse::candidateName)
                .containsExactly(literalPercentCandidate);
    }

    @Test
    void filtersLiteralBackslashInCandidateName() {
        String uniqueSuffix = UUID.randomUUID().toString();
        String literalBackslashCandidate = "Alex\\Example " + uniqueSuffix;
        repository.saveAll(List.of(
                analysis(literalBackslashCandidate, 60),
                analysis("AlexExample " + uniqueSuffix, 60)));
        repository.flush();

        AnalysisHistoryService service = new AnalysisHistoryService(repository);
        AnalysisPageResponse response =
                service.search("Alex\\Example " + uniqueSuffix, null, null, 0, 20);

        assertThat(response.content())
                .extracting(AnalysisHistoryItemResponse::candidateName)
                .containsExactly(literalBackslashCandidate);
    }

    private int comparePostgresUuid(UUID left, UUID right) {
        int mostSignificantBitsComparison =
                Long.compareUnsigned(left.getMostSignificantBits(), right.getMostSignificantBits());
        if (mostSignificantBitsComparison != 0) {
            return mostSignificantBitsComparison;
        }
        return Long.compareUnsigned(left.getLeastSignificantBits(), right.getLeastSignificantBits());
    }

    private AnalysisResult analysis(String candidateName, int matchScore) {
        return new AnalysisResult(
                candidateName,
                matchScore,
                List.of("Java", "Spring Boot", "PostgreSQL", "REST APIs", "Maven"),
                List.of("Docker", "Cloud deployment", "Automated testing"),
                List.of(
                        "How would you design a REST API?",
                        "How do you test a Spring service?",
                        "How have you used PostgreSQL indexes?"));
    }

    private void setCreatedAt(AnalysisResult result, Instant createdAt) {
        entityManager.getEntityManager()
                .createNativeQuery("UPDATE analysis_results SET created_at = :createdAt WHERE id = :id")
                .setParameter("createdAt", Timestamp.from(createdAt))
                .setParameter("id", result.getId())
                .executeUpdate();
    }
}
