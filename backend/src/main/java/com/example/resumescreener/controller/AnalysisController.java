package com.example.resumescreener.controller;

import java.net.URI;
import java.util.UUID;

import com.example.resumescreener.dto.AnalysisHistoryItemResponse;
import com.example.resumescreener.dto.AnalysisPageResponse;
import com.example.resumescreener.dto.AnalysisResultResponse;
import com.example.resumescreener.dto.ResumeAnalysisRequest;
import com.example.resumescreener.service.AnalysisHistoryService;
import com.example.resumescreener.service.ResumeAnalysisService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.servlet.support.ServletUriComponentsBuilder;

@RestController
@RequestMapping("/api/analyses")
public class AnalysisController {

    private final ResumeAnalysisService resumeAnalysisService;
    private final AnalysisHistoryService analysisHistoryService;

    public AnalysisController(
            ResumeAnalysisService resumeAnalysisService,
            AnalysisHistoryService analysisHistoryService) {
        this.resumeAnalysisService = resumeAnalysisService;
        this.analysisHistoryService = analysisHistoryService;
    }

    @PostMapping
    public ResponseEntity<AnalysisResultResponse> createAnalysis(@RequestBody ResumeAnalysisRequest request) {
        AnalysisResultResponse response = resumeAnalysisService.analyze(request);
        URI location = ServletUriComponentsBuilder.fromCurrentRequest()
                .path("/{id}")
                .buildAndExpand(response.id())
                .toUri();
        return ResponseEntity.created(location).body(response);
    }

    @GetMapping
    public AnalysisPageResponse getAnalyses(
            @RequestParam(required = false) String candidateName,
            @RequestParam(required = false) Integer minScore,
            @RequestParam(required = false) Integer maxScore,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        return analysisHistoryService.search(candidateName, minScore, maxScore, page, size);
    }

    @GetMapping("/{id}")
    public AnalysisHistoryItemResponse getAnalysis(@PathVariable UUID id) {
        return analysisHistoryService.getById(id);
    }
}
