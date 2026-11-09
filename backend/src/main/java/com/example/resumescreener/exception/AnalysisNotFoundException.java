package com.example.resumescreener.exception;

public class AnalysisNotFoundException extends RuntimeException {

    public AnalysisNotFoundException() {
        super("Analysis not found.");
    }
}
