package com.example.resumescreener.service;

import java.util.Locale;
import java.util.UUID;

import com.example.resumescreener.dto.AnalysisHistoryItemResponse;
import com.example.resumescreener.dto.AnalysisPageResponse;
import com.example.resumescreener.entity.AnalysisResult;
import com.example.resumescreener.exception.AnalysisNotFoundException;
import com.example.resumescreener.exception.InvalidAnalysisQueryException;
import com.example.resumescreener.repository.AnalysisResultRepository;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.stereotype.Service;

import jakarta.persistence.criteria.Predicate;

@Service
public class AnalysisHistoryService {

    public static final int DEFAULT_PAGE = 0;
    public static final int DEFAULT_SIZE = 20;
    public static final int MAX_PAGE_SIZE = 100;

    private final AnalysisResultRepository analysisResultRepository;

    public AnalysisHistoryService(AnalysisResultRepository analysisResultRepository) {
        this.analysisResultRepository = analysisResultRepository;
    }

    public AnalysisPageResponse search(
            String candidateName,
            Integer minScore,
            Integer maxScore,
            int page,
            int size) {
        validateQuery(candidateName, minScore, maxScore, page, size);

        String normalizedCandidateName =
                candidateName == null ? null : candidateName.trim().toLowerCase(Locale.ROOT);
        Pageable pageable = PageRequest.of(
                page,
                size,
                Sort.by(Sort.Order.desc("createdAt"), Sort.Order.desc("id")));
        Page<AnalysisResult> results = analysisResultRepository.findAll(
                createSpecification(normalizedCandidateName, minScore, maxScore),
                pageable);

        return new AnalysisPageResponse(
                results.getContent().stream().map(AnalysisHistoryService::toResponse).toList(),
                results.getNumber(),
                results.getSize(),
                results.getTotalElements(),
                results.getTotalPages());
    }

    public AnalysisHistoryItemResponse getById(UUID id) {
        AnalysisResult result = analysisResultRepository.findById(id)
                .orElseThrow(AnalysisNotFoundException::new);
        return toResponse(result);
    }

    private void validateQuery(
            String candidateName,
            Integer minScore,
            Integer maxScore,
            int page,
            int size) {
        if (candidateName != null
                && (candidateName.isBlank()
                        || candidateName.length() > AnalysisInputValidator.MAX_CANDIDATE_NAME_LENGTH)) {
            throw new InvalidAnalysisQueryException("Candidate name filter is invalid.");
        }
        validateScore("Minimum score", minScore);
        validateScore("Maximum score", maxScore);
        if (minScore != null && maxScore != null && minScore > maxScore) {
            throw new InvalidAnalysisQueryException("Minimum score must not exceed maximum score.");
        }
        if (page < 0) {
            throw new InvalidAnalysisQueryException("Page must be zero or greater.");
        }
        if (size < 1 || size > MAX_PAGE_SIZE) {
            throw new InvalidAnalysisQueryException("Page size must be between 1 and 100.");
        }
    }

    private void validateScore(String name, Integer score) {
        if (score != null && (score < 0 || score > 100)) {
            throw new InvalidAnalysisQueryException(name + " must be between 0 and 100.");
        }
    }

    private Specification<AnalysisResult> createSpecification(
            String candidateName,
            Integer minScore,
            Integer maxScore) {
        return (root, query, criteriaBuilder) -> {
            Predicate predicate = criteriaBuilder.conjunction();
            if (candidateName != null) {
                String escapedName = candidateName
                        .replace("\\", "\\\\")
                        .replace("%", "\\%")
                        .replace("_", "\\_");
                predicate = criteriaBuilder.and(
                        predicate,
                        criteriaBuilder.like(
                                criteriaBuilder.lower(root.get("candidateName")),
                                "%" + escapedName + "%",
                                '\\'));
            }
            if (minScore != null) {
                predicate = criteriaBuilder.and(
                        predicate,
                        criteriaBuilder.greaterThanOrEqualTo(root.get("matchScore"), minScore));
            }
            if (maxScore != null) {
                predicate = criteriaBuilder.and(
                        predicate,
                        criteriaBuilder.lessThanOrEqualTo(root.get("matchScore"), maxScore));
            }
            return predicate;
        };
    }

    private static AnalysisHistoryItemResponse toResponse(AnalysisResult result) {
        return new AnalysisHistoryItemResponse(
                result.getId(),
                result.getCreatedAt(),
                result.getCandidateName(),
                result.getMatchScore(),
                result.getMatchingSkills(),
                result.getSkillGaps(),
                result.getInterviewQuestions());
    }
}
