package com.example.resumescreener.service;

import com.example.resumescreener.dto.CriterionAssessment;
import com.example.resumescreener.dto.OpenAiAnalysisResponse;
import com.example.resumescreener.dto.OpenAiAnalysisResponse.CriterionRating;
import com.example.resumescreener.dto.ValidatedAnalysisResult;
import com.example.resumescreener.exception.InvalidAnalysisResponseException;
import org.springframework.stereotype.Component;

@Component
public class AnalysisResponseValidator {

    public ValidatedAnalysisResult validate(OpenAiAnalysisResponse response) {
        if (response == null) {
            throw new InvalidAnalysisResponseException("OpenAI analysis response must be provided.");
        }

        return new ValidatedAnalysisResult(
                validateCriterion("Required skills", response.requiredSkills()),
                validateCriterion("Relevant experience", response.relevantExperience()),
                validateCriterion("Seniority and scope", response.seniorityAndScope()),
                validateCriterion(
                        "Nice-to-have skills and domain relevance",
                        response.niceToHaveSkillsAndDomainRelevance()),
                response.matchingSkills(),
                response.skillGaps(),
                response.interviewQuestions());
    }

    private CriterionAssessment validateCriterion(String name, CriterionRating criterion) {
        if (criterion == null || criterion.rating() == null) {
            throw new InvalidAnalysisResponseException(name + " rating must be provided.");
        }
        if (criterion.rating() < 0 || criterion.rating() > 100) {
            throw new InvalidAnalysisResponseException(name + " rating must be between 0 and 100.");
        }
        if (criterion.rationale() == null || criterion.rationale().isBlank()) {
            throw new InvalidAnalysisResponseException(name + " rationale must not be blank.");
        }
        return new CriterionAssessment(criterion.rating(), criterion.rationale());
    }
}
