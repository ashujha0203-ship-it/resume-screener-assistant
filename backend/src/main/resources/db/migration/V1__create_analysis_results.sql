CREATE TABLE analysis_results
(
    id                  UUID                     NOT NULL PRIMARY KEY,
    candidate_name      VARCHAR(200),
    match_score         INTEGER                  NOT NULL,
    matching_skills     JSONB                    NOT NULL,
    skill_gaps          JSONB                    NOT NULL,
    interview_questions JSONB                    NOT NULL,
    created_at          TIMESTAMP WITH TIME ZONE NOT NULL,
    CONSTRAINT chk_analysis_results_match_score
        CHECK (match_score BETWEEN 0 AND 100),
    CONSTRAINT chk_analysis_results_matching_skills
        CHECK (jsonb_typeof(matching_skills) = 'array' AND jsonb_array_length(matching_skills) = 5),
    CONSTRAINT chk_analysis_results_skill_gaps
        CHECK (jsonb_typeof(skill_gaps) = 'array' AND jsonb_array_length(skill_gaps) = 3),
    CONSTRAINT chk_analysis_results_interview_questions
        CHECK (jsonb_typeof(interview_questions) = 'array' AND jsonb_array_length(interview_questions) = 3)
);
