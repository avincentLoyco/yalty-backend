module WeeklyReports
  class Index < UseCase
    def initialize(year)
      @year = year
    end

    def call
      [
        {
          id: 1,
          type: "weekly_report",
          employee_id: 1,
          date_from: "01/01/2018",
          date_to: "01/07/2018",
          worked: 42.00,
          planned: 40.00,
          bank_holidays: 0.0,
          absences: 0.0,
          difference: "+2.00",
          status: :approved,
        },
        {
          id: 2,
          type: "weekly_report",
          employee_id: 1,
          date_from: "01/08/2018",
          date_to: "01/15/2018",
          worked: 40.00,
          planned: 40.00,
          bank_holidays: 0.0,
          absences: 0.0,
          difference: "0.00",
          status: :to_correct,
        },
      ]
    end
  end
end
