class HolidayRepresenter < BaseRepresenter
  def complete
    {
      date: date
    }
      .merge(basic)
  end

  private

  def date
    resource.date.strftime("%d/%m")
  end
end
