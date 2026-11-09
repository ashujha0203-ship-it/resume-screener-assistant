package com.example.resumescreener.exception;

public class OpenAiClientException extends RuntimeException {

    private final Failure failure;
    private final Integer httpStatus;

    public OpenAiClientException(Failure failure, String message) {
        this(failure, null, message);
    }

    public OpenAiClientException(Failure failure, Integer httpStatus, String message) {
        super(message);
        this.failure = failure;
        this.httpStatus = httpStatus;
    }

    public Failure getFailure() {
        return failure;
    }

    public Integer getHttpStatus() {
        return httpStatus;
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
