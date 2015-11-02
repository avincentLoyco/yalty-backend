class AssignCollection
  attr_reader :resource, :collection, :collection_name, :collection_ids

  def initialize(resource, collection, collection_name)
    @resource         = resource
    @collection       = collection.to_a
    @collection_name  = collection_name
    @collection_ids   = collection_name.singularize + '_ids='
  end

  def call
    assign_records
  end

  private

  def assign_records
    ids.each do |id|
      related = Account.current.send(collection_name).find(id)
      resource.send(collection_name).push(related)
    end
  end

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
