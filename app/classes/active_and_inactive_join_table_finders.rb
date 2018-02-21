class ActiveAndInactiveJoinTableFinders
  attr_reader :resource_class, :account_id, :join_table_class

  def initialize(resource_class, join_table_class, account_id)
    @resource_class = resource_class
    @join_table_class = join_table_class
    @account_id = account_id
  end

  def active
    return active_for_account_related if resource_class.attribute_names.include?("account_id")
    active_for_not_account_related
  end

  def inactive
    return inactive_for_account_related if resource_class.attribute_names.include?("account_id")
    inactive_for_non_account_related
  end

  def without_join_tables_assigned
    join_table_symbol = join_table_class.model_name.collection.to_sym
    resource_class.includes(join_table_symbol).where(join_table_symbol => { id: nil }).pluck(:id)
  end

  def assigned_ids
    active_assigned = JoinTableWithEffectiveTill.new(join_table_class, account_id).call
    active_assigned.map { |active| active["#{resource_class.model_name.element}_id"] }
  end

  private

  def active_for_account_related
    resource_class.where(
      "id IN (?) AND account_id = ?", assigned_ids + without_join_tables_assigned, account_id
    )
  end

  def active_for_not_account_related
    resource_class
      .joins(:time_off_category)
      .where(time_off_categories: { account_id: account_id })
      .where(id: assigned_ids + without_join_tables_assigned)
  end

  def inactive_for_account_related
    resource_class.where("id NOT IN (?) AND account_id = ?", active.pluck(:id), account_id)
  end

  def inactive_for_non_account_related
    resource_class
      .joins(:time_off_category)
      .where(time_off_categories: { account_id: account_id })
      .where.not(id: active.pluck(:id))
  end
end
