package com.example.resumescreener.dto;

import java.util.List;

public record AnalysisPageResponse(
        List<AnalysisHistoryItemResponse> content,
        int page,
        int size,
        long totalElements,
        int totalPages) {

    public AnalysisPageResponse {
        content = List.copyOf(content);
    }
}
