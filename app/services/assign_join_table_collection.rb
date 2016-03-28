class AssignJoinTableCollection
  attr_reader :resource, :resource_name_as_attribute, :collection, :collection_name,
    :collection_model_name, :join_table_model, :join_table_model_association,
    :collection_name_as_attribute_with_id, :join_table_model_extra_attributes

  JOIN_TABLE_MODELS = [EmployeeTimeOffPolicy.to_s, WorkingPlaceTimeOffPolicy.to_s].freeze
  # attr_reader :resource, :collection, :collection_name, :collection_model_name

  def initialize(resource, id_hash_array, collection_name, opts = {})
    @resource = resource
    @resource_name_as_attribute = resource.class.to_s.tableize.singularize
    @collection = id_hash_array.present? ? id_hash_array.map { |id_hash| id_hash[:id] } : []
    @collection_name = collection_name
    @collection_model_name = collection_name.classify.constantize
    @collection_name_as_attribute_with_id = "#{collection_name.singularize}_id"
    @join_table_model = find_join_model
    @join_table_model_association = join_table_model.to_s.tableize
    @join_table_model_extra_attributes = opts
  end

  def call
    raise_fail unless resource.respond_to?(collection_name)
    remove_from_resource_collection
    add_to_resource_collection
  end

  private

  def remove_from_resource_collection
    resource.send(join_table_model_association)
            .where.not(collection_name_as_attribute_with_id => collection)
            .destroy_all
  end

  def add_to_resource_collection
    to_be_assigned.each do |member_id|
      attributes =
        {
          resource_name_as_attribute => resource,
          collection_name_as_attribute_with_id => member_id
        }.merge(join_table_model_extra_attributes)
      join_table_model.create!(attributes)
    end
  end

  def fetch_collection(collection_of_ids)
    collection = collection_model_name.where(id: collection_of_ids)
    raise_fail unless collection.size == collection_of_ids.size
    collection
  end

  def to_be_assigned
    already_assigned = resource.send(join_table_model_association)
                               .pluck(collection_name_as_attribute_with_id)
    collection - already_assigned
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
end
