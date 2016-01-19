class AssignJoinTableCollection
  attr_reader :resource, :collection, :collection_name, :collection_model_name

  def initialize(resource, id_hash_array, collection_name)
    @resource         = resource
    @collection       = id_hash_array.present? ? id_hash_array.map { |id_hash| id_hash[:id] } : []
    @collection_name  = collection_name
    @collection_model_name = collection_name.classify.constantize
  end

  def call
    raise_fail unless resource.respond_to?(collection_name)
    remove_from_resource_collection
    add_to_resource_collection
  end

  private

  def remove_from_resource_collection
    resource.send(collection_name)
      .where.not(id: collection)
      .destroy_all
  end

  def add_to_resource_collection
    to_be_assigned.each do |member_id|
      resource.send(collection_name) << collection_model_name.find(member_id)
    end
  end

  def to_be_assigned
    already_assigned = resource.send(collection_name).pluck(:id)
    collection - already_assigned
  end

  def raise_fail
    message = "Join table for #{resource.class} and #{collection_model_name} does not exists"
    fail ActiveRecord::RecordNotFound, message
  end
end
