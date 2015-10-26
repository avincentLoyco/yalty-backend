module Api::V1
  class BaseRepresenter
    attr_reader :resource

    def initialize(resource)
      @resource = resource
    end

    def basic(_ = {})
      if resource.present?
        {
          id: resource.id,
          type: resource_type
        }
      else
        {}
      end
    end

    private

    def resource_type
      @resource_type ||= resource.class.name.underscore.gsub('/', '_')
    end
  end
end
