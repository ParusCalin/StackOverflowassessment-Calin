{{ config(materialized='table') }}

with first_answer as (
  select
    question_id,
    min(answer_created_at) as first_answered_at
  from {{ ref('stg_answers') }}
  group by 1
),
accepted as (
  
  select
    answer_id,
    answer_created_at as accepted_at
  from {{ ref('stg_answers') }}
),
q as (
  select
    question_id,
    asked_at,
    accepted_answer_id,
    answer_count
  from {{ ref('stg_questions') }}
)

select
  q.question_id,
  q.asked_at,
  fa.first_answered_at,
  ac.accepted_at,
  q.answer_count,
  case when fa.first_answered_at is not null
       then timestamp_diff(fa.first_answered_at, q.asked_at, hour) end as hours_to_first_answer,
  case when ac.accepted_at is not null
       then timestamp_diff(ac.accepted_at, q.asked_at, hour) end as hours_to_accepted,
  case when q.answer_count = 0 then 1 else 0 end as is_unanswered,     -- no answers at all
  case when q.accepted_answer_id is null then 1 else 0 end as is_unaccepted -- no accepted answer
from q
left join first_answer fa using (question_id)
left join accepted     ac on ac.answer_id = q.accepted_answer_id