module V1
  class HolidayRepresenter < BaseRepresenter
    def complete
      {
        date: date,
        name: resource.name,
        id:   resource.try(:id),
        type: resource_type,
      }
    end

    private

    def date
      resource.date.strftime("%d/%m")
    end
  end
end
