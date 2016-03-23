module Api::V1
  class BaseRepresenter
    attr_reader :resource, :current_user

    def initialize(resource, current_user = nil)
      @resource = resource
      @current_user = current_user
    end

    def basic(_ = {})
      return unless resource.present?
      {
        id: resource.id,
        type: resource_type
      }
    end

    private

    def resource_type
      @resource_type ||= resource.class.name.underscore.tr('/', '_')
    end
  end
end
