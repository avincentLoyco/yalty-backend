class FindSequenceJoinTableInTime
  include API::V1::Exceptions

  attr_reader :join_tables, :new_effective_at, :join_table_resource, :resource, :resource_class

  def initialize(join_tables, new_effective_at, resource, join_table_resource)
    @join_tables = join_tables
    @new_effective_at = new_effective_at.try(:to_date)
    @join_table_resource = join_table_resource
    @resource = resource
    @resource_class = resource.class.model_name.singular + '_id'
  end

  def call
    return [] unless join_tables.present?
    verify_if_not_at_reset_policy
    verify_if_resource_not_duplicated
    join_tables_to_delete = []
    join_tables_to_delete.push(current_join_table, next_join_table) if new_effective_at
    join_tables_to_delete.push(duplicated_at_previous_effective_at)
    join_tables_to_delete.compact
  end

  def duplicated_at_previous_effective_at
    return unless join_table_resource
    previous = previous_join_table(join_table_resource.effective_at).try(:send, resource_class)
    next_join_table(join_table_resource.effective_at, previous) if previous
  end

  def current_join_table
    @current_join_table ||= find_join_table_by_effective_at_and_category
  end

  def next_join_table(effective_at = new_effective_at, current_resource = resource.id)
    next_table =
      join_tables
      .where('effective_at > ?', effective_at.to_date)
      .order(:effective_at)
      .first

    return next_table if next_table.try(:send, resource_class) == current_resource
  end

  def previous_join_table(effective_at = new_effective_at)
    join_tables
      .where('effective_at < ?', effective_at)
      .order(:effective_at)
      .last
  end

  def find_join_table_by_effective_at_and_category
    return unless new_effective_at
    return join_tables.find_by(effective_at: new_effective_at) unless resource.is_a?(TimeOffPolicy)
    join_tables.find_by(
      effective_at: new_effective_at, time_off_category: resource.time_off_category
    )
  end

  def verify_if_resource_not_duplicated
    return unless current_join_table.try(:send, resource_class) == resource.id
    raise InvalidResourcesError.new(
      join_tables.first.class, ['Join Table with given date and resource already exists']
    )
  end

  def verify_if_not_at_reset_policy
    employee = join_tables.first.employee

    return unless current_join_table && current_join_table.related_resource.reset? &&
      employee.contract_periods.none? { |period| period.include?(new_effective_at) }
    raise InvalidResourcesError.new(
      join_tables.first.class, ['Can not assign in reset resource effective at']
    )
  end
end
