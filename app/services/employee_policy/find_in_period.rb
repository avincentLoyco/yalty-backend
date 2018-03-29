module EmployeePolicy
  #================================================================================================
  # EmployeePolicy::FindInPeriod class
  #================================================================================================
  # Parent class for Employee Policies finders
  # Receives params:
  # - period_to_search - period in which employee join tables will be found
  # - parent_table_id  - represents parent table for given employee join table
  #                      eg. employee_time_off_policies parent_table_id is time_off_category_id
  #                      more info can be found in finder classes that inherit this class
  # - employee         - if passed: employee policies are found for that employee
  #                      if not passed: employee policies are found for current account
  #================================================================================================

  class FindInPeriod
    include API::V1::Exceptions
    BEGINNING_OF_NEXT_DAY = 1.day
    DEFAULT_FILTERS       = [:filter_employee].freeze

    attr_reader :start_date, :end_date, :parent_table_id, :employee

    def self.call(period_to_search:, parent_table_id: nil, employee: nil)
      new(
        period_to_search: period_to_search,
        parent_table_id: parent_table_id,
        employee: employee
      ).call
    end

    protected

    def initialize(period_to_search:, parent_table_id: nil, employee: nil)
      @start_date      = calculated_start_date(period_to_search.start_date)
      @end_date        = period_to_search.end_date
      @parent_table_id = parent_table_id
      @employee        = employee
    end

    def filters(join_table_filters)
      join_table_filters.inject({ effective_at: start_date...end_date }) do |filters, filter|
        filters.merge(send(filter))
      end
    end

    private

    def calculated_start_date(start_date)
      raise InvalidResourcesError.new(start_date, "Start date must be provided") if start_date.nil?
      start_date + BEGINNING_OF_NEXT_DAY
    end

    def filter_employee
      employee.present? ? { employee: employee } : {}
    end
  end
end
