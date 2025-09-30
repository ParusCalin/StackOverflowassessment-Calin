Insighta — Stack Overflow: Topics Needing Answers

This project answers “which topics have the highest need for answers?” using the public Stack Overflow sample data, modeled in BigQuery with dbt, and visualized in Looker Studio.

Public Links

Looker Studio (public): https://lookerstudio.google.com/reporting/0c65108c-312c-49e9-bd9d-5c5dca43843a

BigQuery (public read):

stackoverflowproject-473614.dbt_cparus.fact_question_lifecycle

stackoverflowproject-473614.dbt_cparus.topic_health_daily

Delivery doc (public Google Doc): https://docs.google.com/document/d/1dO-OjGSBNkc-BH4RVQjy1CKWJVWdlV5GNGfSn5TuxgA/edit?tab=t.0

If the report shows no data publicly, set the data source Credentials = Viewer’s credentials in Looker Studio and grant BigQuery Data Viewer to allAuthenticatedUsers on the tables above.

Architecture (star-ish)

Raw sources — dataset: Stack_Overflow_assessment

questions_raw — questions (with <tag>-wrapped tag list)

answers_raw — answers

bridge_question_tag — (question ↔ tag) bridge derived from questions_raw.tags

dim_date — calendar table

Staging (dbt views) — dataset: dbt_cparus

stg_questions — normalized questions (question_id, asked_at, etc.)

stg_answers — only answers whose question_id exists in questions (clean FK)

stg_bridge_question_tag — cleaned bridge (lowercased, non-empty tags)

Facts (dbt tables) — dataset: dbt_cparus

fact_question_lifecycle — accumulating fact (1 row per question)
Fields: asked_at, first_answered_at, accepted_at, hours_to_first_answer, flags is_unanswered, is_unaccepted

topic_health_daily — periodic snapshot (by date_day, tag)
Fields: questions_asked, questions_unanswered, questions_unaccepted, rates, p50_ttf_hours, not_accepted_within_7d(_rate)

Conformed dimensions

dim_tag (distinct tags)

dim_date (calendar)

Join keys

questions_raw.id → stg_questions.question_id

answers_raw.parent_id → stg_answers.question_id

bridge_question_tag.question_id ↔ stg_questions.question_id

Snapshot agg joins: question_id, grouped by date_day, tag

questions_raw ──▶ stg_questions ──┐
                                  ├──▶ fact_question_lifecycle ──┐
answers_raw ──▶ stg_answers ──────┘                              │
                                                                  ├──▶ topic_health_daily (daily by date_day, tag)
bridge_question_tag ─▶ stg_bridge_question_tag ───────────────────┘
dim_tag, dim_date (conformed) join on tag / date_day


Note: topic_health_daily is materialized as a table (partitioned by date_day, clustered by tag). If needed, a one-off BigQuery DDL can recreate it equivalently from the staging models.

Repo Structure
/ (repo)
  dbt_project.yml
  models/
    sources.yml
    schema.yml
    staging/
      stackoverflow/
        stg_questions.sql
        stg_answers.sql
        stg_bridge_question_tag.sql
    marts/
      core/
        dim_tag.sql
        fact_question_lifecycle.sql
        topic_health_daily.sql
  README.md

How to Run (dbt Cloud)

Configure BigQuery connection (service account with BigQuery Job User + dataset write access).

In Studio, save & Commit changes.

Run:

dbt build        # builds models + runs tests
# If needed:
dbt build --full-refresh


Verify tables in BigQuery:
fact_question_lifecycle, topic_health_daily.

Tests

schema.yml includes not_null, unique, and relationships tests on keys.

Metric Definitions

questions_asked — count of questions per (date_day, tag).

questions_unanswered — count with answer_count = 0.

questions_unaccepted — count with accepted_answer_id IS NULL.

unanswered_rate = questions_unanswered / questions_asked.

unaccepted_rate = questions_unaccepted / questions_asked.

not_accepted_within_7d — count where accepted_at IS NULL or accepted_at ≥ asked_at + 7 days.

not_accepted_within_7d_rate = not_accepted_within_7d / questions_asked.

p50_ttf_hours — median time-to-first-answer at the question level, then aggregated daily/tag (median at question, averaged in the daily rollup).

For prioritization we emphasize not_accepted_within_7d_rate and p50_ttf_hours (timely useful answers), with unanswered_rate as a red flag for zero-response gaps.

Dashboard Design (Looker Studio)

Page 1 – Overview & KPIs

Controls: Tag dropdown, Volume filter (questions_asked ≥ 100)

KPIs (AVG unless noted): unanswered_rate, not_accepted_within_7d_rate, p50_ttf_hours (Number), plus questions_asked (SUM)

Table “Top tags”: tag, questions_asked (SUM), unanswered_rate (AVG), not_accepted_within_7d_rate (AVG), p50_ttf_hours (AVG); sort by not_accepted_within_7d_rate desc, then p50_ttf_hours desc

Page 2 – Prioritization

Bubble: X=not_accepted_within_7d_rate (AVG), Y=p50_ttf_hours (AVG), Size=questions_asked (SUM), filter questions_asked ≥ 100. Enable Apply filter and place a detail table beneath for extended “tooltip”.

Page 3 – Trends by Tag

Time series: unaccepted_rate (AVG) and/or unanswered_rate (AVG) by date_day; optional filter questions_asked ≥ 10 to reduce noise. Use Tag dropdown to drill.

Assumptions & Trade-offs

stg_answers keeps only answers with an existing question (enforces FK for clean joins).

Daily metrics computed over all questions for that date_day + tag; very rare tags filtered at the dashboard level (default questions_asked ≥ 100).

accepted_at can be null if acceptance happens outside the sample’s answer window → not_accepted_within_7d is conservative.

Region/location: US. Public read on final tables for Looker Studio.

Possible Next Steps

Weighted rates in-warehouse (SUM(numerators)/SUM(denominators) views) for exact rollups across date ranges.

Dim users (asker/answerer), question score/reputation cohorts.

dbt Semantic Layer metrics + scheduled freshness checks.

QA tests for freshness (source freshness) and distributional tests on ratios.
