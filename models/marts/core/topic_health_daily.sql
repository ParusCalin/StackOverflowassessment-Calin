{{ config(
    materialized='table',
    partition_by = { 'field': 'date_day', 'data_type': 'date' },
    cluster_by = ['tag']
) }}

with
l as (select * from {{ ref('fact_question_lifecycle') }}),
b as (select * from {{ ref('stg_bridge_question_tag') }}),
q as (
  select
    question_id,
    date(asked_at) as date_day
  from {{ ref('stg_questions') }}
)

select
  q.date_day,
  b.tag,
  count(*) as questions_asked,
  sum(l.is_unanswered) as questions_unanswered,          -- zero answers
  sum(l.is_unaccepted) as questions_unaccepted,          -- no accepted answer
  safe_divide(sum(l.is_unanswered), count(*)) as unanswered_rate,
  safe_divide(sum(l.is_unaccepted), count(*)) as unaccepted_rate,
  approx_quantiles(l.hours_to_first_answer, 100)[offset(50)] as p50_ttf_hours,
  sum(case
        when l.accepted_at is null
          or l.accepted_at >= timestamp_add(l.asked_at, interval 7 day)
      then 1 else 0 end) as not_accepted_within_7d,
  safe_divide(
    sum(case when l.accepted_at is null
              or l.accepted_at >= timestamp_add(l.asked_at, interval 7 day)
         then 1 else 0 end),
    count(*)
  ) as not_accepted_within_7d_rate
from q
join l using (question_id)
join b using (question_id)
group by 1,2