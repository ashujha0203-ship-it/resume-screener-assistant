package com.example.resumescreener.service;

import java.util.List;

import com.example.resumescreener.dto.CriterionAssessment;
import com.example.resumescreener.dto.ValidatedAnalysisResult;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

class AnalysisScoringServiceTest {

    private final AnalysisScoringService scoringService = new AnalysisScoringService();

    @Test
    void calculatesScoreUsingAgreedWeights() {
        ValidatedAnalysisResult result = result(80, 70, 60, 50);

        assertThat(scoringService.calculateScore(result)).isEqualTo(70);
    }

    @Test
    void mapsAllZeroAndAllHundredRatingsToScoreBoundaries() {
        assertThat(scoringService.calculateScore(result(0, 0, 0, 0))).isZero();
        assertThat(scoringService.calculateScore(result(100, 100, 100, 100))).isEqualTo(100);
    }

    @Test
    void roundsHalfUpAtAndAroundTheHalfBoundary() {
        assertThat(scoringService.calculateScore(result(100, 50, 0, 24))).isEqualTo(57);
        assertThat(scoringService.calculateScore(result(100, 50, 0, 25))).isEqualTo(58);
        assertThat(scoringService.calculateScore(result(100, 50, 0, 26))).isEqualTo(58);
    }

    private ValidatedAnalysisResult result(int required, int experience, int seniority, int niceToHave) {
        return new ValidatedAnalysisResult(
                criterion(required),
                criterion(experience),
                criterion(seniority),
                criterion(niceToHave),
                List.of("one", "two", "three", "four", "five"),
                List.of("one", "two", "three"),
                List.of("one", "two", "three"));
    }

    private CriterionAssessment criterion(int rating) {
        return new CriterionAssessment(rating, "Evidence-based rationale.");
    }
}
