{{ config(
  materialized='table',
  schema='dbt_cparus',
  partition_by = { 'field': 'date_day', 'data_type': 'date' },
  cluster_by = ['tag']
) }}

with
q as (
  select
    question_id,
    date(asked_at) as date_day
  from {{ ref('stg_questions') }}
  where asked_at is not null
),
b as (
  select
    question_id,
    tag
  from {{ ref('stg_bridge_question_tag') }}
  where tag is not null and trim(tag) <> ''
),
l as (
  select *
  from {{ ref('fact_question_lifecycle') }}
)

select
  q.date_day,
  b.tag,
  count(*) as questions_asked,
  sum(case when l.is_unanswered = 1 then 1 else 0 end) as questions_unanswered,
  sum(case when l.is_unaccepted = 1 then 1 else 0 end) as questions_unaccepted,
  safe_divide(sum(case when l.is_unanswered = 1 then 1 else 0 end), count(*)) as unanswered_rate,
  safe_divide(sum(case when l.is_unaccepted = 1 then 1 else 0 end), count(*)) as unaccepted_rate,
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
join b using (question_id)      -- fără tag nu are sens, deci INNER
left join l using (question_id) -- lifecycle poate lipsi
group by 1,2