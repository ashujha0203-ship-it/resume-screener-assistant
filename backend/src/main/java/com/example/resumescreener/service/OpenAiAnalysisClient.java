package com.example.resumescreener.service;

import com.example.resumescreener.dto.OpenAiAnalysisResponse;
import com.example.resumescreener.dto.ResumeAnalysisRequest;

public interface OpenAiAnalysisClient {

    OpenAiAnalysisResponse analyze(ResumeAnalysisRequest request);
}
