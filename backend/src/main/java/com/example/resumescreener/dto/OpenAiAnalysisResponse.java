package com.example.resumescreener.dto;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

import com.fasterxml.jackson.annotation.JsonProperty;

public record OpenAiAnalysisResponse(
        @JsonProperty("required_skills") CriterionRating requiredSkills,
        @JsonProperty("relevant_experience") CriterionRating relevantExperience,
        @JsonProperty("seniority_and_scope") CriterionRating seniorityAndScope,
        @JsonProperty("nice_to_have_skills_and_domain_relevance")
        CriterionRating niceToHaveSkillsAndDomainRelevance,
        @JsonProperty("matching_skills") List<String> matchingSkills,
        @JsonProperty("skill_gaps") List<String> skillGaps,
        @JsonProperty("interview_questions") List<String> interviewQuestions) {

    public OpenAiAnalysisResponse {
        matchingSkills = immutableCopyOrNull(matchingSkills);
        skillGaps = immutableCopyOrNull(skillGaps);
        interviewQuestions = immutableCopyOrNull(interviewQuestions);
    }

    private static List<String> immutableCopyOrNull(List<String> values) {
        return values == null ? null : Collections.unmodifiableList(new ArrayList<>(values));
    }

    public record CriterionRating(Integer rating, String rationale) {
    }
}
