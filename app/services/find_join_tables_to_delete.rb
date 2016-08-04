class FindJoinTablesToDelete
  include API::V1::Exceptions

  attr_reader :join_tables, :new_effective_at, :join_table_resource, :resource, :resource_class

  def initialize(join_tables, new_effective_at, resource, resource_class, join_table_resource)
    @join_tables = join_tables
    @new_effective_at = new_effective_at.to_date
    @join_table_resource = join_table_resource
    @resource = resource
    @resource_class = resource_class
  end

  def call
    return [] unless join_tables
    join_tables_to_remove = []
    join_tables_to_remove.push(current_join_table, next_join_table)
    join_tables_to_remove.push(duplicated_at_previous_effective_at) if join_table_resource
    join_tables_to_remove.compact
  end

  def duplicated_at_previous_effective_at
    previous = previous_join_table(join_table_resource.effective_at).try(:send, resource_class)
    return next_join_table(join_table_resource.effective_at, previous) if previous
  end

  def current_join_table
    current_join_table = join_tables.find_by(effective_at: new_effective_at)
    verify_if_resource_not_duplicated(current_join_table)
    current_join_table
  end

  def next_join_table(effective_at = new_effective_at, current_resource = resource)
    join_tables
      .where("effective_at > ? AND #{resource_class} = ?", effective_at.to_date, current_resource)
      .order(:effective_at)
      .first
  end

  def previous_join_table(effective_at = new_effective_at)
    join_tables
      .where('effective_at < ?', effective_at)
      .order(:effective_at)
      .last
  end

  def verify_if_resource_not_duplicated(current_join_table)
    return unless current_join_table.try(:send, resource_class) == resource
    raise InvalidResourcesError.new(
      join_tables.first.class, ['Join Table with given date and resource already exists']
    )
  end
end
