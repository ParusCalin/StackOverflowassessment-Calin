-- Keep only answers whose parent question exists in questions_raw
{{ config(materialized='view') }}

with a as (
  select
    id          as answer_id,
    parent_id   as question_id,
    creation_date as answer_created_at,
    score       as answer_score,
    owner_user_id
  from {{ source('so','answers_raw') }}
),
q as (
  select id as question_id
  from {{ source('so','questions_raw') }}
)

select
  a.*
from a
join q using (question_id)