class FindInPeriod
  include API::V1::Exceptions
  BEGINNING_OF_NEXT_DAY = 1.day
  FILTERS               = [:filter_employee, :filter_event_type].freeze

  attr_reader :start_date, :end_date, :event_type, :employee

  def self.call(period_to_search:, event_type: nil, employee: nil)
    new(
      period_to_search: period_to_search,
      event_type: event_type,
      employee: employee
    ).call
  end

  def initialize(period_to_search:, event_type: nil, employee: nil)
    @start_date = calculated_start_date(period_to_search.start_date)
    @end_date   = period_to_search.end_date
    @event_type = event_type
    @employee   = employee
  end

  def call
    Employee::Event.where(filters)
  end

  private

  def calculated_start_date(start_date)
    raise InvalidResourcesError.new(start_date, "Start date must be provided") if start_date.nil?
    start_date + BEGINNING_OF_NEXT_DAY
  end

  def filters
    FILTERS.inject({ effective_at: start_date...end_date }) do |filters, filter|
      filters.merge(send(filter))
    end
  end

  def filter_employee
    employee.present? ? { employee: employee } : { employee: Account.current.employees }
  end

  def filter_event_type
    event_type.present? ? { event_type: event_type } : {}
  end
end
