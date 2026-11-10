package com.example.resumescreener.exception;

public class OpenAiClientException extends RuntimeException {

    private static final int MAX_PROVIDER_ERROR_FIELD_LENGTH = 64;

    private final Failure failure;
    private final Integer httpStatus;
    private final DiagnosticCategory diagnosticCategory;
    private final Integer retryAttempt;
    private final String providerErrorCode;
    private final String providerErrorStatus;

    public OpenAiClientException(Failure failure, String message) {
        this(failure, null, message, defaultCategory(failure, null), null, null);
    }

    public OpenAiClientException(Failure failure, Integer httpStatus, String message) {
        this(failure, httpStatus, message, defaultCategory(failure, httpStatus), null, null);
    }

    public OpenAiClientException(
            Failure failure,
            String message,
            DiagnosticCategory diagnosticCategory,
            Integer retryAttempt,
            Throwable cause) {
        this(failure, null, message, diagnosticCategory, retryAttempt, cause);
    }

    public OpenAiClientException(
            Failure failure,
            Integer httpStatus,
            String message,
            DiagnosticCategory diagnosticCategory,
            Integer retryAttempt,
            Throwable cause) {
        this(failure, httpStatus, message, diagnosticCategory, retryAttempt, null, null, cause);
    }

    public OpenAiClientException(
            Failure failure,
            Integer httpStatus,
            String message,
            DiagnosticCategory diagnosticCategory,
            Integer retryAttempt,
            String providerErrorCode,
            String providerErrorStatus,
            Throwable cause) {
        super(message, cause);
        this.failure = failure;
        this.httpStatus = httpStatus;
        this.diagnosticCategory = diagnosticCategory;
        this.retryAttempt = retryAttempt;
        this.providerErrorCode = sanitizeProviderErrorField(providerErrorCode);
        this.providerErrorStatus = sanitizeProviderErrorField(providerErrorStatus);
    }

    public Failure getFailure() {
        return failure;
    }

    public Integer getHttpStatus() {
        return httpStatus;
    }

    public DiagnosticCategory getDiagnosticCategory() {
        return diagnosticCategory;
    }

    public Integer getRetryAttempt() {
        return retryAttempt;
    }

    public String getProviderErrorCode() {
        return providerErrorCode;
    }

    public String getProviderErrorStatus() {
        return providerErrorStatus;
    }

    private static String sanitizeProviderErrorField(String value) {
        if (value == null
                || value.isEmpty()
                || value.length() > MAX_PROVIDER_ERROR_FIELD_LENGTH
                || !value.matches("[A-Za-z0-9._:-]+")) {
            return null;
        }
        return value;
    }

    private static DiagnosticCategory defaultCategory(Failure failure, Integer httpStatus) {
        if (httpStatus != null && httpStatus >= 400 && httpStatus < 500) {
            return DiagnosticCategory.HTTP_CLIENT_ERROR;
        }
        if (httpStatus != null && httpStatus >= 500 && httpStatus < 600) {
            return DiagnosticCategory.HTTP_SERVER_ERROR;
        }
        return switch (failure) {
            case CONFIGURATION -> DiagnosticCategory.CONFIGURATION;
            case AUTHENTICATION, CLIENT_ERROR, RATE_LIMITED -> DiagnosticCategory.HTTP_CLIENT_ERROR;
            case SERVER_ERROR -> DiagnosticCategory.HTTP_SERVER_ERROR;
            case TIMEOUT, TRANSPORT -> DiagnosticCategory.TRANSPORT_FAILURE;
            case REFUSAL -> DiagnosticCategory.PROVIDER_REFUSAL;
            case INVALID_RESPONSE -> DiagnosticCategory.INVALID_PROVIDER_RESPONSE;
        };
    }

    public enum DiagnosticCategory {
        CONFIGURATION,
        HTTP_CLIENT_ERROR,
        HTTP_SERVER_ERROR,
        TRANSPORT_FAILURE,
        RESPONSE_PARSING_FAILURE,
        INVALID_PROVIDER_RESPONSE,
        PROVIDER_REFUSAL
    }

    public enum Failure {
        CONFIGURATION,
        AUTHENTICATION,
        CLIENT_ERROR,
        RATE_LIMITED,
        TIMEOUT,
        SERVER_ERROR,
        TRANSPORT,
        REFUSAL,
        INVALID_RESPONSE
    }
}
