package com.example.resumescreener;

import com.example.resumescreener.config.OpenAiProperties;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication
@EnableConfigurationProperties(OpenAiProperties.class)
public class ResumeScreenerApplication {

    public static void main(String[] args) {
        SpringApplication.run(ResumeScreenerApplication.class, args);
    }
}
