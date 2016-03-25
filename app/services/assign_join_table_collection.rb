class AssignJoinTableCollection
  attr_reader :resource, :resource_name_as_attribute, :collection_name,
    :collection_model_name, :join_table_model, :join_table_model_association,
    :join_table_model_attributes, :assigned_collection

  JOIN_TABLE_MODELS = [EmployeeTimeOffPolicy.to_s, WorkingPlaceTimeOffPolicy.to_s].freeze

  def initialize(resource, join_table_attribute_hash_array, collection_name)
    @resource = resource
    @resource_name_as_attribute = resource.class.to_s.tableize.singularize
    @collection_name = collection_name
    @collection_model_name = collection_name.classify.constantize
    @join_table_model = find_join_model
    @join_table_model_association = join_table_model.to_s.tableize
    @join_table_model_attributes = join_table_attribute_hash_array
    @assigned_collection = []
  end

  def call
    raise_fail unless resource.respond_to?(collection_name)
    to_be_assigned, to_be_removed = to_be_assigned_and_removed
    remove_from_resource_collection(to_be_removed)
    add_to_resource_collection(to_be_assigned)
    update_balances unless assigned_collection.blank?
  end

  private

  def get_extra_attributes(hash_array)
    return [] unless hash_array.present?
    hash_array.map { |hash| hash.reject { |k, _v| k == 'id' } }
  end

  def get_collection_ids(hash_array)
    return [] unless hash_array.present?
    hash_array.map { |id_hash| id_hash[:id] }
  end

  def remove_from_resource_collection(hash_array)
    join_table_collection = resource.send(join_table_model_association)
    hash_array.each do |attributes_hash|
      join_models = join_table_collection.where(attributes_hash)
      join_models.first.destroy if
       join_models.first.present? && verify_if_deletable(join_models.first)
    end
  end

  def verify_if_deletable(join_model)
    ValidateDeletabilityOfTimeOffPolicyJoinTable.new(join_model).call
  end

  def add_to_resource_collection(hash_array)
    hash_array.each do |attributes_hash|
      assigned_collection << join_table_model.create!(attributes_hash)
    end
  end

  def to_be_assigned_and_removed
    already_assigned = resource.send(join_table_model_association).map do |joins_table_model|
      joins_table_model.as_json(except: :id)
    end
    [join_table_model_attributes - already_assigned, already_assigned - join_table_model_attributes]
  end

  def raise_fail
    message = "Join table for #{resource.class} and #{collection_model_name} does not exists"
    raise ActiveRecord::RecordNotFound, message
  end

  def find_join_model
    resource_model_name = resource.class.to_s
    collection_model_name = collection_name.classify
    possible_names = get_possible_model_names(resource_model_name, collection_model_name)
    possible_names.each do |join_table_model_name|
      return join_table_model_name.constantize if JOIN_TABLE_MODELS.include?(join_table_model_name)
    end
    raise_fail
  end

  def get_possible_model_names(name_a, name_b)
    [name_a + name_b, name_b + name_a]
  end

  def update_balances
    assigned_collection.map do |assigned|
      ManageEmployeeBalances.new(assigned).call
    end
  end
end
