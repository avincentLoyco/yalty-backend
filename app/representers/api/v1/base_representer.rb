module Api::V1
  class BaseRepresenter
    attr_reader :resource

    def initialize(resource)
      @resource = resource
    end

    def basic(_ = {})
      return unless resource.present?
      {
        id: resource.id,
        type: resource_type,
      }
    end

    private

    def resource_type
      @resource_type ||= resource.class.name.underscore.tr("/", "_")
    end

    def related_resources(join_table, related_id = nil, employee_id = nil, join_table_id = nil)
      resources =
        JoinTableWithEffectiveTill
        .new(join_table, Account.current.id, related_id, employee_id, join_table_id)
        .call
      resources.map { |join_hash| join_table.new(join_hash) }
    end
  end
end
