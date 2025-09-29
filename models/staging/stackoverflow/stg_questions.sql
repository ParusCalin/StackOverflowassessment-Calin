{{ config(materialized='view') }}

select
  id as question_id,
  creation_date as asked_at,
  accepted_answer_id,
  answer_count,
  view_count,
  score,
  tags,
  owner_user_id
from {{ source('so','questions_raw') }}