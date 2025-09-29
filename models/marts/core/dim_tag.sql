{{ config(materialized='view') }}

select distinct
  tag
from {{ ref('stg_bridge_question_tag') }}