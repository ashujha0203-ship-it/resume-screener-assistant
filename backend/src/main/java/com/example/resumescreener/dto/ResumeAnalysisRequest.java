package com.example.resumescreener.dto;

public record ResumeAnalysisRequest(
        String candidateName,
        String jobDescription,
        String resume) {
}
