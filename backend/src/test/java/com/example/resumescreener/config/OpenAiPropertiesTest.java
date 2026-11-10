package com.example.resumescreener.config;

import java.time.Duration;

import org.junit.jupiter.api.Test;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.boot.test.context.runner.ApplicationContextRunner;
import org.springframework.context.annotation.Configuration;

import static org.assertj.core.api.Assertions.assertThat;

class OpenAiPropertiesTest {

    private static final String DEFAULT_ENDPOINT =
            "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions";

    private final ApplicationContextRunner contextRunner = new ApplicationContextRunner()
            .withUserConfiguration(OpenAiPropertiesConfiguration.class);

    @Test
    void bindsDefaultsWithoutAnApiKey() {
        contextRunner.run(context -> {
            assertThat(context).hasNotFailed();
            OpenAiProperties properties = context.getBean(OpenAiProperties.class);

            assertThat(properties.getApiKey()).isNull();
            assertThat(properties.isApiKeyConfigured()).isFalse();
            assertThat(properties.getModel()).isEqualTo("gemini-3.5-flash-lite");
            assertThat(properties.getEndpoint()).isEqualTo(DEFAULT_ENDPOINT);
            assertThat(properties.getConnectTimeout()).isEqualTo(Duration.ofSeconds(5));
            assertThat(properties.getReadTimeout()).isEqualTo(Duration.ofSeconds(30));
        });
    }

    @Test
    void treatsBlankApiKeyAsUnconfigured() {
        contextRunner
                .withPropertyValues("gemini.api-key=")
                .run(context -> {
                    assertThat(context).hasNotFailed();
                    assertThat(context.getBean(OpenAiProperties.class).isApiKeyConfigured()).isFalse();
                });
    }

    @Test
    void bindsOptionalApiKeyAndEnvironmentOverrides() {
        contextRunner
                .withPropertyValues(
                        "gemini.api-key=test-key",
                        "gemini.model=test-model",
                        "gemini.endpoint=https://example.test/chat/completions",
                        "gemini.connect-timeout=2s",
                        "gemini.read-timeout=10s")
                .run(context -> {
                    assertThat(context).hasNotFailed();
                    OpenAiProperties properties = context.getBean(OpenAiProperties.class);

                    assertThat(properties.getApiKey()).isEqualTo("test-key");
                    assertThat(properties.isApiKeyConfigured()).isTrue();
                    assertThat(properties.getModel()).isEqualTo("test-model");
                    assertThat(properties.getEndpoint()).isEqualTo("https://example.test/chat/completions");
                    assertThat(properties.getConnectTimeout()).isEqualTo(Duration.ofSeconds(2));
                    assertThat(properties.getReadTimeout()).isEqualTo(Duration.ofSeconds(10));
                });
    }

    @Configuration(proxyBeanMethods = false)
    @EnableConfigurationProperties(OpenAiProperties.class)
    static class OpenAiPropertiesConfiguration {
    }
}
