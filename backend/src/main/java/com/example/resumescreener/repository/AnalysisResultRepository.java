package com.example.resumescreener.repository;

import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;

import com.example.resumescreener.entity.AnalysisResult;

public interface AnalysisResultRepository extends JpaRepository<AnalysisResult, UUID> {
}
