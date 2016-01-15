class AssignJoinTableCollection
  attr_reader :resource, :collection, :collection_name, :join_table_model, :join_model_association,
              :collection_name_id_format

  JOIN_TABLE_MODELS = [EmployeeTimeOffPolicy , WorkingPlaceTimeOffPolicy]

  def initialize(resource, id_hash_array, collection_name)
    @resource         = resource
    @collection       = id_hash_array.present? ? id_hash_array.map { |id_hash| id_hash[:id] } : []
    @collection_name  = collection_name
    @collection_name_id_format = "#{collection_name.singularize}_id"
    @join_table_model = find_join_model
    @join_model_association = join_table_model.to_s.tableize
  end

  def call
    remove_from_resource_collection
    add_to_resource_collection
  end

  private

  def remove_from_resource_collection
    resource.send(join_model_association).where.not(collection_name_id_format => collection)
            .destroy_all
  end

  def add_to_resource_collection
    resouce_name_as_attribute = resource.class.to_s.tableize.singularize
    collection_name_as_attribute = collection_name_id_format
    to_be_assigned.each do |member_id|
      attributes =
        {
          resouce_name_as_attribute => resource,
          collection_name_as_attribute => member_id,
        }
      join_table_model.create!(attributes)
    end
  end

  def to_be_assigned
    already_assigned = resource.send(join_model_association).pluck(collection_name_id_format)
    collection - already_assigned
  end

  def join_model?(model_name)
    JOIN_TABLE_MODELS.each do |join_model|
      return true if join_model.to_s == model_name
    end
    false
  end

  def find_join_model
    resource_model_name = resource.class.to_s
    collection_model_name = collection_name.classify
    possible_names = get_possible_model_names(resource_model_name, collection_model_name)
    possible_names.each do |join_model_name|
      return join_model_name.constantize if join_model?(join_model_name)
    end
    message = "Join table for #{resource_model_name} and #{collection_model_name} does not exists"
    fail ActiveRecord::RecordNotFound, message
  end

  def get_possible_model_names(name_a,name_b)
    [name_a+name_b, name_b+name_a]
  end
end
