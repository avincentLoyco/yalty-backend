class FindJoinTablesToDelete
  include API::V1::Exceptions

  attr_reader :join_tables, :new_effective_at, :join_table_resource, :resource, :resource_class

  def initialize(join_tables, new_effective_at, resource, join_table_resource)
    @join_tables = join_tables
    @new_effective_at = new_effective_at.to_date
    @join_table_resource = join_table_resource
    @resource = resource
    @resource_class = resource.class.model_name.singular + '_id'
  end

  def call
    return [] unless join_tables.present?
    verify_if_resource_not_duplicated
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
    @current_join_table ||=
      if join_tables.first.class.column_names.include?('time_off_category_id')
        join_tables.find_by(
          effective_at: new_effective_at, time_off_category: resource.time_off_category
        )
      else
        join_tables.find_by(effective_at: new_effective_at)
      end
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

  def verify_if_resource_not_duplicated
    return unless current_join_table.try(:send, resource_class) == resource.id
    raise InvalidResourcesError.new(
      join_tables.first.class, ['Join Table with given date and resource already exists']
    )
  end
end
