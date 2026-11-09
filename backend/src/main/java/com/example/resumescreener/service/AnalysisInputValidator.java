package com.example.resumescreener.service;

import com.example.resumescreener.dto.ResumeAnalysisRequest;
import com.example.resumescreener.exception.InvalidAnalysisInputException;
import org.springframework.stereotype.Component;

@Component
public class AnalysisInputValidator {

    public static final int MAX_CANDIDATE_NAME_LENGTH = 200;
    public static final int MAX_JOB_DESCRIPTION_LENGTH = 20_000;
    public static final int MAX_RESUME_LENGTH = 30_000;

    public void validate(ResumeAnalysisRequest request) {
        if (request == null) {
            throw new InvalidAnalysisInputException("Analysis request must be provided.");
        }

        validateRequiredText("Job description", request.jobDescription(), MAX_JOB_DESCRIPTION_LENGTH);
        validateRequiredText("Resume", request.resume(), MAX_RESUME_LENGTH);
        validateOptionalText("Candidate name", request.candidateName(), MAX_CANDIDATE_NAME_LENGTH);
    }

    private void validateRequiredText(String fieldName, String value, int maxLength) {
        if (value == null || value.isBlank()) {
            throw new InvalidAnalysisInputException(fieldName + " must not be blank.");
        }
        validateLength(fieldName, value, maxLength);
    }

    private void validateOptionalText(String fieldName, String value, int maxLength) {
        if (value != null) {
            validateLength(fieldName, value, maxLength);
        }
    }

    private void validateLength(String fieldName, String value, int maxLength) {
        if (value.length() > maxLength) {
            throw new InvalidAnalysisInputException(
                    fieldName + " must not exceed " + maxLength + " characters.");
        }
    }
}
