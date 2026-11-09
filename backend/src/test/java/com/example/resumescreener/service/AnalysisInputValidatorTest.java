package com.example.resumescreener.service;

import com.example.resumescreener.dto.ResumeAnalysisRequest;
import com.example.resumescreener.exception.InvalidAnalysisInputException;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class AnalysisInputValidatorTest {

    private final AnalysisInputValidator validator = new AnalysisInputValidator();

    @Test
    void acceptsValidInputAtMaximumLengthsAndOptionalName() {
        ResumeAnalysisRequest request = new ResumeAnalysisRequest(
                repeatedText(AnalysisInputValidator.MAX_CANDIDATE_NAME_LENGTH),
                repeatedText(AnalysisInputValidator.MAX_JOB_DESCRIPTION_LENGTH),
                repeatedText(AnalysisInputValidator.MAX_RESUME_LENGTH));

        assertThatCode(() -> validator.validate(request)).doesNotThrowAnyException();
        assertThatCode(() -> validator.validate(new ResumeAnalysisRequest(
                null, "Job details", "Resume details"))).doesNotThrowAnyException();
    }

    @Test
    void rejectsMissingRequestAndBlankRequiredFields() {
        assertThatThrownBy(() -> validator.validate(null))
                .isInstanceOf(InvalidAnalysisInputException.class)
                .hasMessage("Analysis request must be provided.");
        assertThatThrownBy(() -> validator.validate(new ResumeAnalysisRequest(null, " ", "Resume")))
                .isInstanceOf(InvalidAnalysisInputException.class)
                .hasMessage("Job description must not be blank.");
        assertThatThrownBy(() -> validator.validate(new ResumeAnalysisRequest(null, "Job details", "\t")))
                .isInstanceOf(InvalidAnalysisInputException.class)
                .hasMessage("Resume must not be blank.");
    }

    @Test
    void rejectsOversizedFieldsWithoutIncludingTheirContentsInErrors() {
        String oversizedResume = repeatedText(AnalysisInputValidator.MAX_RESUME_LENGTH + 1);

        assertThatThrownBy(() -> validator.validate(
                new ResumeAnalysisRequest(null, "Job details", oversizedResume)))
                .isInstanceOf(InvalidAnalysisInputException.class)
                .hasMessage("Resume must not exceed 30000 characters.")
                .hasMessageNotContaining(oversizedResume);
        assertThatThrownBy(() -> validator.validate(new ResumeAnalysisRequest(
                repeatedText(AnalysisInputValidator.MAX_CANDIDATE_NAME_LENGTH + 1),
                "Job details",
                "Resume details")))
                .isInstanceOf(InvalidAnalysisInputException.class)
                .hasMessage("Candidate name must not exceed 200 characters.");
        assertThatThrownBy(() -> validator.validate(new ResumeAnalysisRequest(
                null,
                repeatedText(AnalysisInputValidator.MAX_JOB_DESCRIPTION_LENGTH + 1),
                "Resume details")))
                .isInstanceOf(InvalidAnalysisInputException.class)
                .hasMessage("Job description must not exceed 20000 characters.");
    }

    private String repeatedText(int length) {
        return "x".repeat(length);
    }
}
