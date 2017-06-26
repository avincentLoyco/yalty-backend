module Api
  module V1
    class AvailableModuleRepresenter < BaseRepresenter
      def complete
        {
          id: resource.id,
          name: resource.name,
          enabled: resource.enabled,
          free: resource.free
        }
      end
    end
  end
end
