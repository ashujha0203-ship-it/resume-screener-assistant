package com.example.resumescreener.service;

import java.util.ArrayList;
import java.util.List;

import com.example.resumescreener.dto.OpenAiAnalysisResponse;
import com.example.resumescreener.dto.OpenAiAnalysisResponse.CriterionRating;
import com.example.resumescreener.dto.ValidatedAnalysisResult;
import com.example.resumescreener.exception.InvalidAnalysisResponseException;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.EnumSource;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class AnalysisResponseValidatorTest {

    private final AnalysisResponseValidator validator = new AnalysisResponseValidator();

    @Test
    void mapsValidProviderResponseToValidatedResult() {
        ValidatedAnalysisResult validated = validator.validate(validResponse());

        assertThat(validated.requiredSkills().rating()).isEqualTo(80);
        assertThat(validated.requiredSkills().rationale()).isEqualTo("Required skills are demonstrated.");
        assertThat(validated.relevantExperience().rating()).isEqualTo(70);
        assertThat(validated.seniorityAndScope().rating()).isEqualTo(60);
        assertThat(validated.niceToHaveSkillsAndDomainRelevance().rating()).isEqualTo(50);
        assertThat(validated.matchingSkills()).containsExactly("Java", "Spring", "SQL", "REST", "Testing");
        assertThat(validated.skillGaps()).containsExactly("Cloud", "Docker", "Monitoring");
        assertThat(validated.interviewQuestions()).containsExactly("Question 1?", "Question 2?", "Question 3?");
    }

    @ParameterizedTest
    @EnumSource(Criterion.class)
    void acceptsZeroAndOneHundredForEveryCriterion(Criterion criterion) {
        assertThat(validator.validate(withCriterion(validResponse(), criterion, new CriterionRating(0, "Evidence."))))
                .isNotNull();
        assertThat(validator.validate(withCriterion(validResponse(), criterion, new CriterionRating(100, "Evidence."))))
                .isNotNull();
    }

    @Test
    void rejectsNullResponseAndMissingCriteria() {
        assertThatThrownBy(() -> validator.validate(null))
                .isInstanceOf(InvalidAnalysisResponseException.class)
                .hasMessage("OpenAI analysis response must be provided.");
        for (Criterion criterion : Criterion.values()) {
            assertThatThrownBy(() -> validator.validate(withCriterion(validResponse(), criterion, null)))
                    .isInstanceOf(InvalidAnalysisResponseException.class)
                    .hasMessageContaining("rating must be provided");
        }
    }

    @ParameterizedTest
    @EnumSource(Criterion.class)
    void rejectsNullRatingsAndRatingsOutsideRange(Criterion criterion) {
        assertInvalidCriterion(criterion, new CriterionRating(null, "Evidence."));
        assertInvalidCriterion(criterion, new CriterionRating(-1, "Evidence."));
        assertInvalidCriterion(criterion, new CriterionRating(101, "Evidence."));
    }

    @ParameterizedTest
    @EnumSource(Criterion.class)
    void rejectsNullOrBlankRationales(Criterion criterion) {
        assertInvalidCriterion(criterion, new CriterionRating(50, null));
        assertInvalidCriterion(criterion, new CriterionRating(50, " \t "));
    }

    @Test
    void rejectsMissingOrIncorrectlySizedLists() {
        assertInvalidLists(null, validResponse().skillGaps(), validResponse().interviewQuestions());
        assertInvalidLists(validResponse().matchingSkills().subList(0, 4),
                validResponse().skillGaps(), validResponse().interviewQuestions());
        List<String> extraMatchingSkill = new ArrayList<>(validResponse().matchingSkills());
        extraMatchingSkill.add("Extra");
        assertInvalidLists(extraMatchingSkill, validResponse().skillGaps(), validResponse().interviewQuestions());

        assertInvalidLists(validResponse().matchingSkills(), null, validResponse().interviewQuestions());
        assertInvalidLists(validResponse().matchingSkills(), List.of("one", "two"),
                validResponse().interviewQuestions());
        assertInvalidLists(validResponse().matchingSkills(), List.of("one", "two", "three", "four"),
                validResponse().interviewQuestions());

        assertInvalidLists(validResponse().matchingSkills(), validResponse().skillGaps(), null);
        assertInvalidLists(validResponse().matchingSkills(), validResponse().skillGaps(), List.of("one", "two"));
        assertInvalidLists(validResponse().matchingSkills(), validResponse().skillGaps(),
                List.of("one", "two", "three", "four"));
    }

    @ParameterizedTest
    @EnumSource(ListField.class)
    void rejectsNullOrBlankItemInEveryList(ListField field) {
        assertInvalidLists(withInvalidListItem(field, null));
        assertInvalidLists(withInvalidListItem(field, " \t "));
    }

    @Test
    void validatedListsAreDefensiveImmutableCopies() {
        OpenAiAnalysisResponse raw = validResponse();
        List<String> originalSkills = new ArrayList<>(raw.matchingSkills());
        ValidatedAnalysisResult result = validator.validate(raw);
        originalSkills.set(0, "Changed");
        List<String> mutableInput = new ArrayList<>(raw.skillGaps());
        ValidatedAnalysisResult copied = new ValidatedAnalysisResult(
                result.requiredSkills(),
                result.relevantExperience(),
                result.seniorityAndScope(),
                result.niceToHaveSkillsAndDomainRelevance(),
                raw.matchingSkills(),
                mutableInput,
                raw.interviewQuestions());
        mutableInput.set(0, "Changed");

        assertThat(result.matchingSkills().get(0)).isEqualTo("Java");
        assertThat(copied.skillGaps().get(0)).isEqualTo("Cloud");
        assertThatThrownBy(() -> result.matchingSkills().add("Another"))
                .isInstanceOf(UnsupportedOperationException.class);
        assertThatThrownBy(() -> result.skillGaps().clear())
                .isInstanceOf(UnsupportedOperationException.class);
    }

    @Test
    void validationErrorsDoNotExposeProviderText() {
        OpenAiAnalysisResponse response = withCriterion(
                validResponse(), Criterion.REQUIRED_SKILLS, new CriterionRating(101, "private provider rationale"));

        assertThatThrownBy(() -> validator.validate(response))
                .isInstanceOf(InvalidAnalysisResponseException.class)
                .hasMessage("Required skills rating must be between 0 and 100.")
                .hasMessageNotContaining("private provider rationale");
    }

    private void assertInvalidCriterion(Criterion criterion, CriterionRating rating) {
        assertThatThrownBy(() -> validator.validate(withCriterion(validResponse(), criterion, rating)))
                .isInstanceOf(InvalidAnalysisResponseException.class);
    }

    private void assertInvalidLists(List<String> matching, List<String> gaps, List<String> questions) {
        OpenAiAnalysisResponse base = validResponse();
        OpenAiAnalysisResponse response = new OpenAiAnalysisResponse(
                base.requiredSkills(),
                base.relevantExperience(),
                base.seniorityAndScope(),
                base.niceToHaveSkillsAndDomainRelevance(),
                matching,
                gaps,
                questions);
        assertThatThrownBy(() -> validator.validate(response))
                .isInstanceOf(InvalidAnalysisResponseException.class);
    }

    private void assertInvalidLists(OpenAiAnalysisResponse response) {
        assertThatThrownBy(() -> validator.validate(response))
                .isInstanceOf(InvalidAnalysisResponseException.class);
    }

    private OpenAiAnalysisResponse withInvalidListItem(ListField field, String invalidItem) {
        OpenAiAnalysisResponse base = validResponse();
        List<String> matchingSkills = new ArrayList<>(base.matchingSkills());
        List<String> skillGaps = new ArrayList<>(base.skillGaps());
        List<String> interviewQuestions = new ArrayList<>(base.interviewQuestions());
        List<String> target = switch (field) {
            case MATCHING_SKILLS -> matchingSkills;
            case SKILL_GAPS -> skillGaps;
            case INTERVIEW_QUESTIONS -> interviewQuestions;
        };
        target.set(0, invalidItem);

        return new OpenAiAnalysisResponse(
                base.requiredSkills(),
                base.relevantExperience(),
                base.seniorityAndScope(),
                base.niceToHaveSkillsAndDomainRelevance(),
                matchingSkills,
                skillGaps,
                interviewQuestions);
    }

    private OpenAiAnalysisResponse withCriterion(
            OpenAiAnalysisResponse response,
            Criterion criterion,
            CriterionRating rating) {
        return new OpenAiAnalysisResponse(
                criterion == Criterion.REQUIRED_SKILLS ? rating : response.requiredSkills(),
                criterion == Criterion.RELEVANT_EXPERIENCE ? rating : response.relevantExperience(),
                criterion == Criterion.SENIORITY_AND_SCOPE ? rating : response.seniorityAndScope(),
                criterion == Criterion.NICE_TO_HAVE ? rating : response.niceToHaveSkillsAndDomainRelevance(),
                response.matchingSkills(),
                response.skillGaps(),
                response.interviewQuestions());
    }

    private OpenAiAnalysisResponse validResponse() {
        return new OpenAiAnalysisResponse(
                new CriterionRating(80, "Required skills are demonstrated."),
                new CriterionRating(70, "Relevant experience is demonstrated."),
                new CriterionRating(60, "Scope is demonstrated."),
                new CriterionRating(50, "Preferred skills are demonstrated."),
                List.of("Java", "Spring", "SQL", "REST", "Testing"),
                List.of("Cloud", "Docker", "Monitoring"),
                List.of("Question 1?", "Question 2?", "Question 3?"));
    }

    private enum Criterion {
        REQUIRED_SKILLS,
        RELEVANT_EXPERIENCE,
        SENIORITY_AND_SCOPE,
        NICE_TO_HAVE
    }

    private enum ListField {
        MATCHING_SKILLS,
        SKILL_GAPS,
        INTERVIEW_QUESTIONS
    }
}
