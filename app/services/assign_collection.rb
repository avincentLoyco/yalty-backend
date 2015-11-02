class AssignCollection
  attr_reader :resource, :collection, :collection_name, :collection_ids

  def initialize(resource, collection, collection_name)
    @resource         = resource
    @collection       = collection
    @collection_name  = collection_name
    @collection_ids   = collection_name.singularize + '_ids='
  end

  def call
    resource.send(collection_ids, ids)
  end

  private

  def ids
    result = collection.map { |item| item[:id] } & valid_ids
    if result.size != collection.size
      fail ActiveRecord::RecordNotFound
    else
      result
    end
  end

  def valid_ids
    Account.current.send(collection_name).map(&:id)
  end
end
