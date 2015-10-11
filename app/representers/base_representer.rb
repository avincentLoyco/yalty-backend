class BaseRepresenter
  attr_reader :resource

  def initialize(resource)
    @resource = resource
  end

  def basic(_ = {})
    {
      id: resource.id,
      type: resource_type
    }
  end

  private

  def resource_type
    @resource_type ||= resource.class.name.underscore
  end
end
