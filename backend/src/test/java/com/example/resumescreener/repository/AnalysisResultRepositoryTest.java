package com.example.resumescreener.repository;

import java.util.List;
import java.util.UUID;

import com.example.resumescreener.entity.AnalysisResult;
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
}
