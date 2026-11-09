package com.example.resumescreener.dto;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

public record AnalysisHistoryItemResponse(
        UUID id,
        Instant createdAt,
        String candidateName,
        int matchScore,
        List<String> matchingSkills,
        List<String> skillGaps,
        List<String> interviewQuestions) {

    public AnalysisHistoryItemResponse {
        matchingSkills = List.copyOf(matchingSkills);
        skillGaps = List.copyOf(skillGaps);
        interviewQuestions = List.copyOf(interviewQuestions);
    }
}
