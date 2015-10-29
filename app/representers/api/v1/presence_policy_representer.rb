module Api::V1
  class PresencePolicyRepresenter < BaseRepresenter
    def complete
      {
        name: resource.name
      }
        .merge(basic)
    end

    def with_relationships
      response = resource.presence_days.map do |attribute|
        PresenceDayRepresenter.new(attribute).complete
      end
      complete.merge(presence_days: response)
    end
  end
end
