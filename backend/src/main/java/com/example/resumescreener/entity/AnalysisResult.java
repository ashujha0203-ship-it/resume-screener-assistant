package com.example.resumescreener.entity;

import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

@Entity
@Table(name = "analysis_results")
public class AnalysisResult {

    @Id
    @Column(nullable = false, updatable = false)
    private UUID id = UUID.randomUUID();

    @Column(name = "candidate_name", length = 200)
    private String candidateName;

    @Column(name = "match_score", nullable = false)
    private int matchScore;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "matching_skills", nullable = false, columnDefinition = "jsonb")
    private List<String> matchingSkills = new ArrayList<>();

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "skill_gaps", nullable = false, columnDefinition = "jsonb")
    private List<String> skillGaps = new ArrayList<>();

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "interview_questions", nullable = false, columnDefinition = "jsonb")
    private List<String> interviewQuestions = new ArrayList<>();

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt = Instant.now();

    protected AnalysisResult() {
    }

    public AnalysisResult(
            String candidateName,
            int matchScore,
            List<String> matchingSkills,
            List<String> skillGaps,
            List<String> interviewQuestions) {
        this.candidateName = candidateName;
        this.matchScore = matchScore;
        this.matchingSkills = new ArrayList<>(matchingSkills);
        this.skillGaps = new ArrayList<>(skillGaps);
        this.interviewQuestions = new ArrayList<>(interviewQuestions);
    }

    public UUID getId() {
        return id;
    }

    public String getCandidateName() {
        return candidateName;
    }

    public int getMatchScore() {
        return matchScore;
    }

    public List<String> getMatchingSkills() {
        return List.copyOf(matchingSkills);
    }

    public List<String> getSkillGaps() {
        return List.copyOf(skillGaps);
    }

    public List<String> getInterviewQuestions() {
        return List.copyOf(interviewQuestions);
    }

    public Instant getCreatedAt() {
        return createdAt;
    }
}
