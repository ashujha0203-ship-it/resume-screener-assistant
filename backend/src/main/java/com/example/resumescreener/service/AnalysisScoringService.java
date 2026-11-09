package com.example.resumescreener.service;

import java.math.BigDecimal;
import java.math.RoundingMode;

import com.example.resumescreener.dto.ValidatedAnalysisResult;
import org.springframework.stereotype.Component;

@Component
public class AnalysisScoringService {

    private static final BigDecimal REQUIRED_SKILLS_WEIGHT = new BigDecimal("0.40");
    private static final BigDecimal RELEVANT_EXPERIENCE_WEIGHT = new BigDecimal("0.30");
    private static final BigDecimal SENIORITY_AND_SCOPE_WEIGHT = new BigDecimal("0.20");
    private static final BigDecimal NICE_TO_HAVE_AND_DOMAIN_WEIGHT = new BigDecimal("0.10");

    public int calculateScore(ValidatedAnalysisResult analysis) {
        BigDecimal weightedScore = BigDecimal.valueOf(analysis.requiredSkills().rating())
                .multiply(REQUIRED_SKILLS_WEIGHT)
                .add(BigDecimal.valueOf(analysis.relevantExperience().rating())
                        .multiply(RELEVANT_EXPERIENCE_WEIGHT))
                .add(BigDecimal.valueOf(analysis.seniorityAndScope().rating())
                        .multiply(SENIORITY_AND_SCOPE_WEIGHT))
                .add(BigDecimal.valueOf(analysis.niceToHaveSkillsAndDomainRelevance().rating())
                        .multiply(NICE_TO_HAVE_AND_DOMAIN_WEIGHT));

        return weightedScore.setScale(0, RoundingMode.HALF_UP).intValueExact();
    }
}
