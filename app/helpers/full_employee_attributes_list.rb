class FullEmployeeAttributesList
  def initialize(account_id, employee_id, effective_at)
    @account_id = account_id
    @employee_id = employee_id
    @effective_at = effective_at.to_date.to_s
  end

  def call
    Employee::AttributeVersion.joins(join_sql).where(where_sql).order(order_sql).select(select_sql)
  end

  private

  def select_sql
    <<-eos
      DISTINCT ON (
        employee_attribute_versions.employee_id,
        employee_attribute_versions.attribute_definition_id,
        employee_attribute_versions.order
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
        employee_attribute_versions.updated_at AS updated_at,
        employee_attribute_versions.order AS order
    eos
  end

  def join_sql
    <<-eos
      INNER JOIN employee_events
        ON employee_attribute_versions.employee_event_id = employee_events.id
      INNER JOIN employee_attribute_definitions
        ON employee_attribute_versions.attribute_definition_id = employee_attribute_definitions.id
    eos
  end

  def where_sql
    <<-eos
      employee_events.effective_at <= '#{@effective_at}'::date
      AND employee_attribute_definitions.account_id = '#{@account_id}'
      AND employee_attribute_versions.employee_id = '#{@employee_id}'
    eos
  end

  def order_sql
    <<-eos
      employee_attribute_versions.employee_id,
      employee_attribute_versions.attribute_definition_id,
      employee_attribute_versions.order,
      employee_events.effective_at DESC
    eos
  end
end
