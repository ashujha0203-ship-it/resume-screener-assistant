package com.example.resumescreener.service;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

import com.example.resumescreener.entity.AnalysisResult;
import com.example.resumescreener.exception.AnalysisNotFoundException;
import com.example.resumescreener.exception.InvalidAnalysisQueryException;
import com.example.resumescreener.repository.AnalysisResultRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.domain.Specification;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class AnalysisHistoryServiceTest {

    @Mock
    private AnalysisResultRepository repository;

    @Test
    void searchesWithValidatedFiltersAndNewestFirstStableSort() {
        AnalysisHistoryService service = new AnalysisHistoryService(repository);
        AnalysisResult result = analysis("Jordan Lee", 82);
        when(repository.findAll(
                org.mockito.ArgumentMatchers.<Specification<AnalysisResult>>any(),
                any(Pageable.class)))
                .thenReturn(new PageImpl<>(List.of(result)));

        var response = service.search(" Jordan ", 40, 90, 2, 10);

        ArgumentCaptor<Pageable> pageableCaptor = ArgumentCaptor.forClass(Pageable.class);
        verify(repository).findAll(
                org.mockito.ArgumentMatchers.<Specification<AnalysisResult>>any(),
                pageableCaptor.capture());
        Pageable pageable = pageableCaptor.getValue();
        assertThat(pageable.getPageNumber()).isEqualTo(2);
        assertThat(pageable.getPageSize()).isEqualTo(10);
        assertThat(pageable.getSort().getOrderFor("createdAt").getDirection().name()).isEqualTo("DESC");
        assertThat(pageable.getSort().getOrderFor("id").getDirection().name()).isEqualTo("DESC");
        assertThat(response.content()).hasSize(1);
        assertThat(response.content().getFirst().candidateName()).isEqualTo("Jordan Lee");
        assertThat(response.content().getFirst().matchScore()).isEqualTo(82);
    }

    @Test
    void rejectsInvalidFiltersBeforeCallingRepository() {
        AnalysisHistoryService service = new AnalysisHistoryService(repository);

        assertThatThrownBy(() -> service.search(null, -1, null, 0, 20))
                .isInstanceOf(InvalidAnalysisQueryException.class);
        assertThatThrownBy(() -> service.search(null, null, 101, 0, 20))
                .isInstanceOf(InvalidAnalysisQueryException.class);
        assertThatThrownBy(() -> service.search(null, 80, 70, 0, 20))
                .isInstanceOf(InvalidAnalysisQueryException.class);
        assertThatThrownBy(() -> service.search(" ", null, null, 0, 20))
                .isInstanceOf(InvalidAnalysisQueryException.class);
        assertThatThrownBy(() -> service.search("x".repeat(201), null, null, 0, 20))
                .isInstanceOf(InvalidAnalysisQueryException.class);
        assertThatThrownBy(() -> service.search(null, null, null, -1, 20))
                .isInstanceOf(InvalidAnalysisQueryException.class);
        assertThatThrownBy(() -> service.search(null, null, null, 0, 0))
                .isInstanceOf(InvalidAnalysisQueryException.class);
        assertThatThrownBy(() -> service.search(null, null, null, 0, 101))
                .isInstanceOf(InvalidAnalysisQueryException.class);

        verifyNoInteractions(repository);
    }

    @Test
    void retrievesExistingRecordById() {
        AnalysisHistoryService service = new AnalysisHistoryService(repository);
        AnalysisResult result = analysis("Jordan Lee", 82);
        when(repository.findById(result.getId())).thenReturn(Optional.of(result));

        var response = service.getById(result.getId());

        assertThat(response.id()).isEqualTo(result.getId());
        assertThat(response.createdAt()).isEqualTo(result.getCreatedAt());
        assertThat(response.candidateName()).isEqualTo("Jordan Lee");
        assertThat(response.matchScore()).isEqualTo(82);
        assertThat(response.matchingSkills()).hasSize(5);
        assertThat(response.skillGaps()).hasSize(3);
        assertThat(response.interviewQuestions()).hasSize(3);
    }

    @Test
    void reportsMissingRecordWithoutExposingIdentifier() {
        AnalysisHistoryService service = new AnalysisHistoryService(repository);
        UUID id = UUID.randomUUID();
        when(repository.findById(eq(id))).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.getById(id))
                .isInstanceOf(AnalysisNotFoundException.class)
                .hasMessage("Analysis not found.");
    }

    private AnalysisResult analysis(String candidateName, int score) {
        return new AnalysisResult(
                candidateName,
                score,
                List.of("Java", "Spring", "SQL", "REST", "Testing"),
                List.of("Cloud", "Docker", "Kubernetes"),
                List.of("Question one?", "Question two?", "Question three?"));
    }
}
