package com.example.resumescreener.config;

import java.util.List;

import com.example.resumescreener.dto.AnalysisPageResponse;
import com.example.resumescreener.service.AnalysisHistoryService;
import com.example.resumescreener.service.ResumeAnalysisService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.context.annotation.Import;
import org.springframework.http.HttpHeaders;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.options;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest
@Import(WebCorsConfiguration.class)
@TestPropertySource(properties =
        "app.cors.allowed-origins=http://localhost:5000,https://app.example")
class WebCorsConfigurationTest {

    @MockitoBean
    private ResumeAnalysisService resumeAnalysisService;

    @MockitoBean
    private AnalysisHistoryService analysisHistoryService;

    @Autowired
    private MockMvc mockMvc;

    @Test
    void allowsConfiguredOriginWithoutCredentialsOrExposedHeaders() throws Exception {
        when(analysisHistoryService.search(null, null, null, 0, 20))
                .thenReturn(new AnalysisPageResponse(List.of(), 0, 20, 0, 0));

        mockMvc.perform(get("/api/analyses")
                        .header(HttpHeaders.ORIGIN, "http://localhost:5000"))
                .andExpect(status().isOk())
                .andExpect(header().string(
                        HttpHeaders.ACCESS_CONTROL_ALLOW_ORIGIN,
                        "http://localhost:5000"))
                .andExpect(header().doesNotExist(HttpHeaders.ACCESS_CONTROL_ALLOW_CREDENTIALS))
                .andExpect(header().doesNotExist(HttpHeaders.ACCESS_CONTROL_EXPOSE_HEADERS));
    }

    @Test
    void rejectsUnconfiguredOrigin() throws Exception {
        mockMvc.perform(get("/api/analyses")
                        .header(HttpHeaders.ORIGIN, "https://untrusted.example"))
                .andExpect(status().isForbidden())
                .andExpect(header().doesNotExist(HttpHeaders.ACCESS_CONTROL_ALLOW_ORIGIN));
    }

    @Test
    void allowsMultipleConfiguredOriginsAndRejectsAnUnlistedOrigin() throws Exception {
        when(analysisHistoryService.search(null, null, null, 0, 20))
                .thenReturn(new AnalysisPageResponse(List.of(), 0, 20, 0, 0));

        for (String origin : List.of("http://localhost:5000", "https://app.example")) {
            mockMvc.perform(get("/api/analyses").header(HttpHeaders.ORIGIN, origin))
                    .andExpect(status().isOk())
                    .andExpect(header().string(HttpHeaders.ACCESS_CONTROL_ALLOW_ORIGIN, origin));
        }

        mockMvc.perform(get("/api/analyses")
                        .header(HttpHeaders.ORIGIN, "https://unlisted.example"))
                .andExpect(status().isForbidden())
                .andExpect(header().doesNotExist(HttpHeaders.ACCESS_CONTROL_ALLOW_ORIGIN));
    }

    @Test
    void allowsPreflightOnlyForConfiguredMethodsAndHeaders() throws Exception {
        for (String method : List.of("GET", "POST", "OPTIONS")) {
            mockMvc.perform(options("/api/analyses")
                            .header(HttpHeaders.ORIGIN, "http://localhost:5000")
                            .header(HttpHeaders.ACCESS_CONTROL_REQUEST_METHOD, method)
                            .header(
                                    HttpHeaders.ACCESS_CONTROL_REQUEST_HEADERS,
                                    "content-type,accept"))
                    .andExpect(status().isOk())
                    .andExpect(header().string(
                            HttpHeaders.ACCESS_CONTROL_ALLOW_ORIGIN,
                            "http://localhost:5000"))
                    .andExpect(header().string(
                            HttpHeaders.ACCESS_CONTROL_ALLOW_METHODS,
                            org.hamcrest.Matchers.allOf(
                                    org.hamcrest.Matchers.containsString("GET"),
                                    org.hamcrest.Matchers.containsString("POST"),
                                    org.hamcrest.Matchers.containsString("OPTIONS"))))
                    .andExpect(header().string(
                            HttpHeaders.ACCESS_CONTROL_ALLOW_HEADERS,
                            org.hamcrest.Matchers.allOf(
                                    org.hamcrest.Matchers.containsString("content-type"),
                                    org.hamcrest.Matchers.containsString("accept"))))
                    .andExpect(header().doesNotExist(
                            HttpHeaders.ACCESS_CONTROL_ALLOW_CREDENTIALS))
                    .andExpect(header().doesNotExist(
                            HttpHeaders.ACCESS_CONTROL_EXPOSE_HEADERS));
        }
    }

    @Test
    void rejectsPreflightForUnsupportedMethod() throws Exception {
        mockMvc.perform(options("/api/analyses")
                        .header(HttpHeaders.ORIGIN, "http://localhost:5000")
                        .header(HttpHeaders.ACCESS_CONTROL_REQUEST_METHOD, "DELETE"))
                .andExpect(status().isForbidden());
    }
}
