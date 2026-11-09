package com.example.resumescreener.dto;

import com.example.resumescreener.exception.InvalidAnalysisResponseException;

public record CriterionAssessment(int rating, String rationale) {

    public CriterionAssessment {
        if (rating < 0 || rating > 100) {
            throw new InvalidAnalysisResponseException("Analysis criterion rating must be between 0 and 100.");
        }
        if (rationale == null || rationale.isBlank()) {
            throw new InvalidAnalysisResponseException("Analysis criterion rationale must not be blank.");
        }
    }
}
