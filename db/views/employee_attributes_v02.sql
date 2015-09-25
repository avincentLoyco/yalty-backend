SELECT DISTINCT ON (
  employee_attribute_versions.employee_id,
  employee_attribute_versions.attribute_definition_id
)
  employee_attribute_versions.id AS id,
  employee_attribute_versions.data AS data,
  employee_events.effective_at as effective_at,
  employee_attribute_definitions.name AS attribute_name,
  employee_attribute_definitions.attribute_type AS attribute_type,
  employee_attribute_versions.employee_id AS employee_id,
  employee_attribute_versions.id AS employee_attribute_version_id,
  employee_attribute_versions.employee_event_id AS employee_event_id,
  employee_attribute_versions.attribute_definition_id AS attribute_definition_id,
  employee_attribute_versions.created_at AS created_at,
  employee_attribute_versions.updated_at AS updated_at
FROM employee_attribute_versions
INNER JOIN employee_events
  ON employee_attribute_versions.employee_event_id = employee_events.id
INNER JOIN employee_attribute_definitions
  ON employee_attribute_versions.attribute_definition_id = employee_attribute_definitions.id
WHERE employee_events.effective_at <= NOW()
ORDER BY
  employee_attribute_versions.employee_id,
  employee_attribute_versions.attribute_definition_id,
  employee_events.effective_at DESC
