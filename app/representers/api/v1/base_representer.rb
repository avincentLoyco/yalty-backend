module Api::V1
  class BaseRepresenter
    attr_reader :resource, :requester_is_manager

    def initialize(resource, is_manager=nil)
      @resource = resource
      @requester_is_manager = is_manager
    end

    def basic(_ = {})
      if resource.present?
        {
          id: resource.id,
          type: resource_type
        }
      else
        nil
      end
    end

    private

    def resource_type
      @resource_type ||= resource.class.name.underscore.tr('/', '_')
    end
  end
end
