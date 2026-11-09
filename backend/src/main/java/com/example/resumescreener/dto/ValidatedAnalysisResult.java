package com.example.resumescreener.dto;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

import com.example.resumescreener.exception.InvalidAnalysisResponseException;

public record ValidatedAnalysisResult(
        CriterionAssessment requiredSkills,
        CriterionAssessment relevantExperience,
        CriterionAssessment seniorityAndScope,
        CriterionAssessment niceToHaveSkillsAndDomainRelevance,
        List<String> matchingSkills,
        List<String> skillGaps,
        List<String> interviewQuestions) {

    public ValidatedAnalysisResult {
        requireCriterion(requiredSkills);
        requireCriterion(relevantExperience);
        requireCriterion(seniorityAndScope);
        requireCriterion(niceToHaveSkillsAndDomainRelevance);
        matchingSkills = immutableValidatedCopy("Matching skills", matchingSkills, 5);
        skillGaps = immutableValidatedCopy("Skill gaps", skillGaps, 3);
        interviewQuestions = immutableValidatedCopy("Interview questions", interviewQuestions, 3);
    }

    private static void requireCriterion(CriterionAssessment criterion) {
        if (criterion == null) {
            throw new InvalidAnalysisResponseException("All analysis criteria must be provided.");
        }
    }

    private static List<String> immutableValidatedCopy(String fieldName, List<String> values, int expectedSize) {
        if (values == null || values.size() != expectedSize) {
            throw new InvalidAnalysisResponseException(
                    fieldName + " must contain exactly " + expectedSize + " items.");
        }
        if (values.stream().anyMatch(value -> value == null || value.isBlank())) {
            throw new InvalidAnalysisResponseException(fieldName + " must not contain blank items.");
        }
        return Collections.unmodifiableList(new ArrayList<>(values));
    }

}
