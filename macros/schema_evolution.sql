{% macro detect_new_columns(source_relation, target_relation) -%}
{%- set src_parts = source_relation.split('.') -%}
{%- set tgt_parts = target_relation.split('.') -%}

{%- if src_parts | length == 3 -%}
  {%- set src_db = src_parts[0] -%}
  {%- set src_schema = src_parts[1] -%}
  {%- set src_table = src_parts[2] -%}
{%- elif src_parts | length == 2 -%}
  {%- set src_db = none -%}
  {%- set src_schema = src_parts[0] -%}
  {%- set src_table = src_parts[1] -%}
{%- else -%}
  {{ exceptions.raise_compiler_error('source_relation must be schema.table or db.schema.table') }}
{%- endif -%}

{%- if tgt_parts | length == 3 -%}
  {%- set tgt_db = tgt_parts[0] -%}
  {%- set tgt_schema = tgt_parts[1] -%}
  {%- set tgt_table = tgt_parts[2] -%}
{%- elif tgt_parts | length == 2 -%}
  {%- set tgt_db = none -%}
  {%- set tgt_schema = tgt_parts[0] -%}
  {%- set tgt_table = tgt_parts[1] -%}
{%- else -%}
  {{ exceptions.raise_compiler_error('target_relation must be schema.table or db.schema.table') }}
{%- endif -%}

{# build SQL to read source columns #}
{%- if src_db -%}
  {%- set src_sql -%}
    select column_name, data_type
    from {{ src_db }}.information_schema.columns
    where table_schema = '{{ src_schema.upper() }}'
      and table_name = '{{ src_table.upper() }}'
  {%- endset -%}
{%- else -%}
  {%- set src_sql -%}
    select column_name, data_type
    from information_schema.columns
    where table_schema = '{{ src_schema.upper() }}'
      and table_name = '{{ src_table.upper() }}'
  {%- endset -%}
{%- endif -%}

{# build SQL to read target columns #}
{%- if tgt_db -%}
  {%- set tgt_sql -%}
    select column_name, data_type
    from {{ tgt_db }}.information_schema.columns
    where table_schema = '{{ tgt_schema.upper() }}'
      and table_name = '{{ tgt_table.upper() }}'
  {%- endset -%}
{%- else -%}
  {%- set tgt_sql -%}
    select column_name, data_type
    from information_schema.columns
    where table_schema = '{{ tgt_schema.upper() }}'
      and table_name = '{{ tgt_table.upper() }}'
  {%- endset -%}
{%- endif -%}

{%- set src_results = run_query(src_sql) -%}
{%- set tgt_results = run_query(tgt_sql) -%}

{%- set src_cols = [] -%}
{%- if src_results is not none -%}
  {%- for row in src_results -%}
    {%- set vals = row.values() -%}
    {%- do src_cols.append(vals[0]) -%}
  {%- endfor -%}
{%- endif -%}

{%- set tgt_cols = [] -%}
{%- if tgt_results is not none -%}
  {%- for row in tgt_results -%}
    {%- set vals = row.values() -%}
    {%- do tgt_cols.append(vals[0]) -%}
  {%- endfor -%}
{%- endif -%}

{%- set missing = [] -%}
{%- for col in src_cols -%}
  {%- if col not in tgt_cols -%}
    {%- do missing.append(col) -%}
  {%- endif -%}
{%- endfor -%}

{{ log('Missing columns: ' ~ missing, info=True) }}

{{ return(missing) }}
{%- endmacro %}


{% macro generate_alter_add_columns(source_relation, target_relation, dry_run=true) -%}
{%- set missing = detect_new_columns(source_relation, target_relation) -%}
{%- if missing is none or missing | length == 0 -%}
  {{ log('No missing columns found.', info=True) }}
  {{ return([]) }}
{%- endif -%}

{# Fetch source column types to construct ALTER statements #}
{%- set src_parts = source_relation.split('.') -%}
{%- if src_parts | length == 3 -%}
  {%- set src_db = src_parts[0] -%}
  {%- set src_schema = src_parts[1] -%}
  {%- set src_table = src_parts[2] -%}
{%- else -%}
  {%- set src_db = none -%}
  {%- set src_schema = src_parts[0] -%}
  {%- set src_table = src_parts[1] -%}
{%- endif -%}

{%- if src_db -%}
  {%- set metadata_sql -%}
    select column_name, data_type
    from {{ src_db }}.information_schema.columns
    where table_schema = '{{ src_schema.upper() }}'
      and table_name = '{{ src_table.upper() }}'
  {%- endset -%}
{%- else -%}
  {%- set metadata_sql -%}
    select column_name, data_type
    from information_schema.columns
    where table_schema = '{{ src_schema.upper() }}'
      and table_name = '{{ src_table.upper() }}'
  {%- endset -%}
{%- endif -%}

{%- set meta = run_query(metadata_sql) -%}
{%- set type_map = {} -%}
{%- if meta is not none -%}
  {%- for row in meta -%}
    {%- set vals = row.values() -%}
    {%- do type_map.update({vals[0]: vals[1]}) -%}
  {%- endfor -%}
{%- endif -%}

{%- set alter_statements = [] -%}
{%- for col in missing -%}
  {%- set dtype = type_map.get(col, 'VARCHAR') -%}
  {%- set stmt = 'ALTER TABLE ' ~ target_relation ~ ' ADD COLUMN "' ~ col ~ '" ' ~ dtype ~ ';' -%}
  {%- do alter_statements.append(stmt) -%}
{%- endfor -%}

{{ log('Generated ALTER statements:', info=True) }}
{%- for s in alter_statements -%}
  {{ log(s, info=True) }}
{%- endfor -%}

{%- if not dry_run -%}
  {%- for s in alter_statements -%}
    {%- set _ = run_query(s) -%}
  {%- endfor -%}
  {{ log('Applied ALTER statements.', info=True) }}
{%- else -%}
  {{ log('Dry run - no changes applied. Set dry_run=false to execute.', info=True) }}
{%- endif -%}

{{ return(alter_statements) }}
{%- endmacro %}
