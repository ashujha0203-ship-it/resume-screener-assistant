package com.example.resumescreener.dto;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

public record AnalysisResultResponse(
        UUID id,
        Instant createdAt,
        String candidateName,
        int matchScore,
        CriterionAssessment requiredSkills,
        CriterionAssessment relevantExperience,
        CriterionAssessment seniorityAndScope,
        CriterionAssessment niceToHaveSkillsAndDomainRelevance,
        List<String> matchingSkills,
        List<String> skillGaps,
        List<String> interviewQuestions,
        String advisoryNotice) {

    public AnalysisResultResponse {
        matchingSkills = List.copyOf(matchingSkills);
        skillGaps = List.copyOf(skillGaps);
        interviewQuestions = List.copyOf(interviewQuestions);
    }
}
