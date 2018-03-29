module TimeOffs
  class FindInPeriod
    include API::V1::Exceptions
    BEGINNING_OF_NEXT_DAY = 1.day
    FILTERS               = [:filter_employee, :filter_time_off_category].freeze

    attr_reader :start_time, :end_time, :time_off_category_id, :employee

    def self.call(period_to_search:, time_off_category_id: nil, employee: nil)
      new(
        period_to_search: period_to_search,
        time_off_category_id: time_off_category_id,
        employee: employee
      ).call
    end

    def initialize(period_to_search:, time_off_category_id: nil, employee: nil)
      @start_time           = calculated_start_time(period_to_search.start_date)
      @end_time             = period_to_search.end_date
      @time_off_category_id = time_off_category_id
      @employee             = employee
    end

    def call
      Account.current.time_offs.where(filters)
    end

    private

    def calculated_start_time(start_time)
      raise InvalidResourcesError.new(start_time, "Start date must be provided") if start_time.nil?
      start_time + BEGINNING_OF_NEXT_DAY
    end

    def filters
      FILTERS.inject({ start_time: start_time...end_time }) do |filters, filter|
        filters.merge(send(filter))
      end
    end

    def filter_employee
      employee.present? ? { employee: employee } : {}
    end

    def filter_time_off_category
      time_off_category_id.present? ? { time_off_category_id: time_off_category_id } : {}
    end
  end
end
