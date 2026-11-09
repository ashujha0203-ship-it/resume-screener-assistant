package com.example.resumescreener.service;

import com.example.resumescreener.dto.AnalysisResultResponse;
import com.example.resumescreener.dto.ResumeAnalysisRequest;
import com.example.resumescreener.dto.ValidatedAnalysisResult;
import com.example.resumescreener.entity.AnalysisResult;
import com.example.resumescreener.repository.AnalysisResultRepository;
import org.springframework.stereotype.Service;

@Service
public class ResumeAnalysisService {

    private static final String ADVISORY_NOTICE =
            "This score is decision-support information and is not an automatic hiring decision.";

    private final AnalysisInputValidator inputValidator;
    private final OpenAiAnalysisClient openAiAnalysisClient;
    private final AnalysisResponseValidator responseValidator;
    private final AnalysisScoringService scoringService;
    private final AnalysisResultRepository analysisResultRepository;

    public ResumeAnalysisService(
            AnalysisInputValidator inputValidator,
            OpenAiAnalysisClient openAiAnalysisClient,
            AnalysisResponseValidator responseValidator,
            AnalysisScoringService scoringService,
            AnalysisResultRepository analysisResultRepository) {
        this.inputValidator = inputValidator;
        this.openAiAnalysisClient = openAiAnalysisClient;
        this.responseValidator = responseValidator;
        this.scoringService = scoringService;
        this.analysisResultRepository = analysisResultRepository;
    }

    public AnalysisResultResponse analyze(ResumeAnalysisRequest request) {
        inputValidator.validate(request);

        ValidatedAnalysisResult analysis =
                responseValidator.validate(openAiAnalysisClient.analyze(request));
        int matchScore = scoringService.calculateScore(analysis);

        AnalysisResult entity = new AnalysisResult(
                request.candidateName(),
                matchScore,
                analysis.matchingSkills(),
                analysis.skillGaps(),
                analysis.interviewQuestions());
        AnalysisResult savedEntity = analysisResultRepository.save(entity);

        return new AnalysisResultResponse(
                savedEntity.getId(),
                savedEntity.getCreatedAt(),
                request.candidateName(),
                matchScore,
                analysis.requiredSkills(),
                analysis.relevantExperience(),
                analysis.seniorityAndScope(),
                analysis.niceToHaveSkillsAndDomainRelevance(),
                analysis.matchingSkills(),
                analysis.skillGaps(),
                analysis.interviewQuestions(),
                ADVISORY_NOTICE);
    }
}
