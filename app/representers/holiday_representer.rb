class HolidayRepresenter < BaseRepresenter
  def complete
    {
      date: date,
      name: resource.name
    }
      .merge(basic)
  end

  private

  def date
    resource.date.strftime("%d/%m")
  end
end
