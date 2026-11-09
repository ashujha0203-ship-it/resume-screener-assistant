package com.example.resumescreener.exception;

import java.time.Instant;
import java.util.LinkedHashSet;
import java.util.Set;

import com.example.resumescreener.dto.ApiErrorResponse;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpMethod;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.util.AntPathMatcher;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.MissingServletRequestParameterException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.HttpMediaTypeNotSupportedException;
import org.springframework.web.HttpRequestMethodNotSupportedException;
import org.springframework.web.method.annotation.MethodArgumentTypeMismatchException;
import org.springframework.web.servlet.mvc.method.RequestMappingInfo;
import org.springframework.web.servlet.mvc.method.annotation.RequestMappingHandlerMapping;

import jakarta.servlet.http.HttpServletRequest;

@RestControllerAdvice
public class ApiExceptionHandler {

    private static final Logger LOGGER = LoggerFactory.getLogger(ApiExceptionHandler.class);
    private static final AntPathMatcher PATH_MATCHER = new AntPathMatcher();
    private final RequestMappingHandlerMapping requestMappingHandlerMapping;

    public ApiExceptionHandler(RequestMappingHandlerMapping requestMappingHandlerMapping) {
        this.requestMappingHandlerMapping = requestMappingHandlerMapping;
    }

    @ExceptionHandler({
            InvalidAnalysisInputException.class,
            InvalidAnalysisQueryException.class,
            HttpMessageNotReadableException.class,
            MethodArgumentNotValidException.class,
            MethodArgumentTypeMismatchException.class,
            MissingServletRequestParameterException.class
    })
    public ResponseEntity<ApiErrorResponse> handleBadRequest(Exception exception) {
        return error(HttpStatus.BAD_REQUEST, "INVALID_REQUEST", "The request is invalid.");
    }

    @ExceptionHandler(AnalysisNotFoundException.class)
    public ResponseEntity<ApiErrorResponse> handleNotFound(AnalysisNotFoundException exception) {
        return error(HttpStatus.NOT_FOUND, "ANALYSIS_NOT_FOUND", "Analysis not found.");
    }

    @ExceptionHandler(HttpRequestMethodNotSupportedException.class)
    public ResponseEntity<ApiErrorResponse> handleMethodNotAllowed(
            HttpRequestMethodNotSupportedException exception,
            HttpServletRequest request) {
        HttpStatus status = HttpStatus.METHOD_NOT_ALLOWED;
        HttpHeaders headers = new HttpHeaders();
        headers.setAllow(supportedMethods(exception, request));
        return ResponseEntity.status(status)
                .headers(headers)
                .body(new ApiErrorResponse(
                        Instant.now(),
                        status.value(),
                        "METHOD_NOT_ALLOWED",
                        "The HTTP method is not supported for this endpoint."));
    }

    private Set<HttpMethod> supportedMethods(
            HttpRequestMethodNotSupportedException exception,
            HttpServletRequest request) {
        Set<HttpMethod> methods = new LinkedHashSet<>();
        String contextPath = request.getContextPath();
        String requestPath = request.getRequestURI().substring(contextPath.length());

        for (RequestMappingInfo mapping : requestMappingHandlerMapping.getHandlerMethods().keySet()) {
            boolean matchesPath = mapping.getPatternValues().stream()
                    .anyMatch(pattern -> PATH_MATCHER.match(pattern, requestPath));
            if (matchesPath) {
                mapping.getMethodsCondition().getMethods().stream()
                        .map(method -> HttpMethod.valueOf(method.name()))
                        .forEach(methods::add);
            }
        }

        String[] exceptionMethods = exception.getSupportedMethods();
        if (exceptionMethods != null) {
            for (String method : exceptionMethods) {
                methods.add(HttpMethod.valueOf(method));
            }
        }
        return methods;
    }

    @ExceptionHandler(HttpMediaTypeNotSupportedException.class)
    public ResponseEntity<ApiErrorResponse> handleUnsupportedMediaType(
            HttpMediaTypeNotSupportedException exception) {
        return error(
                HttpStatus.UNSUPPORTED_MEDIA_TYPE,
                "UNSUPPORTED_MEDIA_TYPE",
                "The request media type is not supported.");
    }

    @ExceptionHandler(InvalidAnalysisResponseException.class)
    public ResponseEntity<ApiErrorResponse> handleInvalidAnalysisResponse(
            InvalidAnalysisResponseException exception) {
        return error(
                HttpStatus.BAD_GATEWAY,
                "INVALID_PROVIDER_RESPONSE",
                "The analysis provider returned an unusable response.");
    }

    @ExceptionHandler(OpenAiClientException.class)
    public ResponseEntity<ApiErrorResponse> handleOpenAiClientException(OpenAiClientException exception) {
        return switch (exception.getFailure()) {
            case CONFIGURATION -> error(
                    HttpStatus.SERVICE_UNAVAILABLE,
                    "AI_NOT_CONFIGURED",
                    "Analysis is temporarily unavailable because the AI provider is not configured.");
            case RATE_LIMITED -> error(
                    HttpStatus.SERVICE_UNAVAILABLE,
                    "AI_RATE_LIMITED",
                    "Analysis is temporarily unavailable. Please try again later.");
            case TIMEOUT -> error(
                    HttpStatus.GATEWAY_TIMEOUT,
                    "AI_TIMEOUT",
                    "The analysis provider did not respond in time.");
            case AUTHENTICATION, CLIENT_ERROR, SERVER_ERROR, TRANSPORT, REFUSAL, INVALID_RESPONSE ->
                    error(
                            HttpStatus.BAD_GATEWAY,
                            "AI_PROVIDER_ERROR",
                            "The analysis provider could not complete the request.");
        };
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<ApiErrorResponse> handleUnexpectedException(Exception exception) {
        LOGGER.error("Unexpected API error ({}).", exception.getClass().getSimpleName());
        return error(
                HttpStatus.INTERNAL_SERVER_ERROR,
                "INTERNAL_ERROR",
                "An unexpected error occurred.");
    }

    private ResponseEntity<ApiErrorResponse> error(HttpStatus status, String code, String message) {
        return ResponseEntity.status(status)
                .body(new ApiErrorResponse(Instant.now(), status.value(), code, message));
    }
}
