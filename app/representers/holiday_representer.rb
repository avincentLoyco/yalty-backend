class HolidayRepresenter < BaseRepresenter
  def initialize(holiday)
    @resource = holiday
  end

  def complete
    {
      date: date
    }
    .merge(basic)
  end

  private

  attr_reader :resource

  def date
    resource.date.strftime("%d/%m")
  end
end
