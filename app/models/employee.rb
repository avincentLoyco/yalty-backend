class Employee < ActiveRecord::Base
  include ActsAsIntercomTrigger

  CIVIL_STATUS = { "marriage" => "married", "divorce" => "divorced",
                   "partnership" => "registered partnership", "spouse_death" => "widowed",
                   "partnership_dissolution" => "dissolved partnership",
                   "partner_death" => "dissolved partnership due to death" }.freeze

  RESOURCE_JOIN_TABLES =
    %w(employee_time_off_policies employee_working_places employee_presence_policies).freeze

  MIGRATION_DATE = Rails.configuration.migration_date

  belongs_to :account, inverse_of: :employees, required: true
  belongs_to :user,
    class_name: "Account::User",
    foreign_key: :account_user_id,
    inverse_of: :employee
  belongs_to :manager, class_name: "Account::User"
  has_many :employee_attribute_versions,
    class_name: "Employee::AttributeVersion",
    inverse_of: :employee
  has_many :employee_attributes,
    class_name: "Employee::Attribute",
    inverse_of: :employee
  has_many :events, class_name: "Employee::Event", inverse_of: :employee
  has_many :time_offs
  has_many :employee_balances, class_name: "Employee::Balance"
  has_many :employee_time_off_policies
  has_many :time_off_policies, through: :employee_time_off_policies
  has_many :time_off_categories, -> { uniq }, through: :time_off_policies
  has_many :employee_working_places
  has_many :working_places, through: :employee_working_places
  has_many :employee_presence_policies
  has_many :presence_policies, through: :employee_presence_policies
  has_many :registered_working_times, dependent: :destroy

  validates :user, uniqueness: { scope: :account_id }, allow_nil: true
  validates :user, presence: true, if: :account_user_id_changed?
  validate :hired_event_presence, on: :create

  scope(:active_by_account, lambda do |account_id|
    where(account_id: account_id)
  end)

  scope(:chargeable_at_date, lambda do |date = Time.zone.now|
    related_to_date(date, :eq)
  end)

  scope(:active_at_date, lambda do |date = Time.zone.now|
    related_to_date(date, :gteq)
  end)

  scope(:inactive_at_date, lambda do |date = Time.zone.now|
    where.not(id: active_at_date(date).pluck(:id))
  end)

  scope(:active_user_by_account, lambda do |account_id|
    active_by_account(account_id).where("account_user_id IS NOT NULL")
  end)

  scope(:affected_by_presence_policy, lambda do |presence_policy_id|
    joins(:employee_presence_policies)
      .where(employee_presence_policies: { presence_policy_id: presence_policy_id })
  end)

  scope(:employees_with_time_off_in_range, lambda do |start_date, end_date|
    joins(:time_offs).where(
      '((time_offs.start_time::date BETWEEN ? AND ?) OR
      (time_offs.end_time::date BETWEEN ? AND ?) OR
      (time_offs.end_time::date > ? AND time_offs.start_time::date < ?))',
      start_date, end_date, start_date, end_date, end_date, start_date
    )
  end)

  class << self
    private

    def related_to_date(date, operator)
      joins(:events)
        .where(
          Employee::Event.arel_table[:event_type].eq("hired")
            .and(Employee::Event.arel_table[:effective_at].public_send(operator, date.to_date))
            .or(previous_event_sql(date.to_date))
        )
        .distinct
    end
  end

  class ContractPeriods
    pattr_initialize :employee

    def build
      contract_dates
        .each_slice(2)
        .map { |period| period.first..(period.size > 1 ? period.last : DateTime::Infinity.new) }
    end

    private

    def contract_dates
      employee.persisted? ? dates_for_existing : dates_for_new
    end

    def dates_for_existing
      employee.events.contract_types.reorder(effective_at: :asc).pluck(:effective_at)
    end

    def dates_for_new
      Array.wrap(employee.events.detect(&:contract_border?)&.effective_at)
    end
  end

  class << self
    def active_employee_ratio_per_account(account_id)
      active_employee_count = Employee.active_by_account(account_id).count
      return if active_employee_count.zero?
      active_user_count = Employee.active_user_by_account(account_id).count
      ((active_user_count * 100.0) / active_employee_count).round(2)
    end

    private

    def previous_event_sql(date)
      Arel.sql(
        format("
          'hired' = (
            SELECT employee_events.event_type FROM employee_events
            WHERE employee_events.effective_at < '%<date>s'
            AND employee_events.employee_id = employees.id
            AND employee_events.event_type IN ('hired', 'contract_end')
            ORDER BY employee_events.effective_at DESC
            LIMIT 1
          )
        ", date: date.iso8601)
      )
    end
  end

  def current_hired_for(date)
    events.where("effective_at = ? AND event_type = ?", hired_date_for(date), "hired").first
  end

  def contract_periods_include?(*dates)
    contract_periods.any? do |period|
      if period.last.is_a?(Date::Infinity) || dates.all? { |d| d.is_a?(Date) }
        dates.map { |date| date.to_date.in?(period) }
      else
        dates.map do |date|
          period.first <= date && date <= period.last + 1.day + Employee::Balance::REMOVAL_OFFSET
        end
      end.uniq.eql?([true])
    end
  end

  def fullname
    attributes =
      employee_attributes
      .joins(:attribute_definition)
      .where("employee_attribute_definitions.name IN (?)", %w(firstname lastname))
      .map { |attr| [attr.attribute_name.to_sym, attr.value] }
      .to_h

    "#{attributes[:firstname]} #{attributes[:lastname]}"
  end

  def civil_status_for(date = Time.zone.today)
    civil_status_event = last_civil_status_event_for(date)
    return "single" unless civil_status_event
    CIVIL_STATUS[civil_status_event.event_type]
  end

  def civil_status_date_for(date = Time.zone.today)
    last_civil_status_event_for(date).try(:effective_at)
  end

  def hired_date
    hired_date_for(Time.zone.today)
  end

  def hired_date_for(date)
    date_period = contract_periods.find do |period|
      period.include?(date.to_date) || date.to_date < period.first
    end
    date_period ||= contract_periods.last
    date_period.first
  end

  def contract_end_date
    contract_end_for(hired_date)
  end

  def contract_end_for(date)
    date_period = contract_periods.reverse.map.each_with_index do |period, index|
      if day_difference?(index, date)
        contract_periods.reverse[index + 1]
      elsif period.include?(date.to_date) || date.to_date > period.last
        period
      end
    end.compact.first
    date_period ||= contract_periods.first
    date_period.blank? || date_period.last.is_a?(DateTime::Infinity) ? nil : date_period.last
  end

  def day_difference?(index, date)
    periods = contract_periods.reverse
    return false unless periods.size > 1 && periods[index + 1].present?
    periods[index].first.eql?(date.to_date) &&
      (periods[index].first.mjd - periods[index + 1].last.mjd).eql?(1)
  end

  def contract_periods
    ContractPeriods.new(self).build
  end

  def first_employee_event
    events.hired.reorder("employee_events.effective_at DESC").first
  end

  def active_policy_in_category_at_date(category_id, date = Time.zone.today)
    assigned_time_off_policies_in_category(category_id, date).first
  end

  def active_working_place_at(date = Time.zone.today)
    WorkingPlace.active_for_employee(id, date)
  end

  def active_presence_policy_at(date = Time.zone.today)
    PresencePolicy.active_for_employee(id, date)
  end

  def last_balance_in_category(category_id)
    employee_balances.where(time_off_category_id: category_id).order("effective_at").last
  end

  def assigned_time_off_policies_in_category(category_id, date = Time.zone.today)
    employee_time_off_policies.assigned_at(date).in_category(category_id).limit(3)
  end

  def not_assigned_time_off_policies_in_category(category_id, date = Time.zone.today)
    employee_time_off_policies.not_assigned_at(date).in_category(category_id).limit(2)
  end

  def file_with?(file_id)
    employee_file_ids.include?(file_id)
  end

  def files
    GenericFile.where(id: employee_file_ids)
  end

  def total_amount_of_data
    employee_attribute_versions
      .where("data -> 'attribute_type' = 'File'")
      .sum("(data -> 'size')::float / (1024.0 * 1024.0)").round(2)
  end

  def number_of_files
    employee_attribute_versions.where("data -> 'attribute_type' = 'File'").count
  end

  def first_upcoming_contract_end(date = Time.zone.today)
    events.contract_ends.where("effective_at > ?", date).order(:effective_at).first
  end

  def can_be_hired?
    !contract_periods.last.last.is_a?(DateTime::Infinity)
  end

  def hired_before_migration?
    created_at < MIGRATION_DATE
  end

  def hired_at?(date)
    contract_periods_include?(date)
  end

  def event_at(date:, type:)
    events.where(event_type: type, effective_at: date).first
  end

  private

  def employee_file_ids
    employee_attribute_versions
      .where("data -> 'attribute_type' = 'File'")
      .pluck("data -> 'id'")
  end

  def hired_event_presence
    return if events && events.map(&:event_type).include?("hired")
    errors.add(:events, "Employee must have hired event")
  end

  def last_civil_status_event_for(date)
    @last_civil_status_event_for ||=
      events
      .where("event_type IN (?) AND effective_at <= ?", CIVIL_STATUS.keys, date)
      .order(:effective_at).last
  end
end
