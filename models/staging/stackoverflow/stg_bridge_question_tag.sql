{{ config(materialized='view') }}

select
  question_id,
  lower(trim(tag)) as tag
from {{ source('so','bridge_question_tag') }}
where tag is not null and trim(tag) <> ''