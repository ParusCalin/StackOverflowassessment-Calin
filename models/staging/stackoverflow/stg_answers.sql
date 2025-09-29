{{ config(materialized='view') }}

select
  id as answer_id,
  parent_id as question_id,
  creation_date as answer_created_at,
  score as answer_score,
  owner_user_id
from {{ source('so','answers_raw') }}