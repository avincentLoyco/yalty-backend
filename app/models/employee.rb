class Employee < ActiveRecord::Base
  include ActsAsIntercomTrigger

  CIVIL_STATUS = { 'marriage' => 'married', 'divorce' => 'divorced',
                   'partnership' => 'registered partnership', 'spouse_death' => 'widowed',
                   'partnership_dissolution' => 'dissolved partnership',
                   'partner_death' => 'dissolved partnership due to death' }.freeze

  belongs_to :account, inverse_of: :employees, required: true
  belongs_to :user, class_name: 'Account::User', foreign_key: :account_user_id
  has_many :employee_attribute_versions,
    class_name: 'Employee::AttributeVersion',
    inverse_of: :employee
  has_many :employee_attributes,
    class_name: 'Employee::Attribute',
    inverse_of: :employee
  has_many :events, class_name: 'Employee::Event', inverse_of: :employee
  has_many :time_offs
  has_many :employee_balances, class_name: 'Employee::Balance'
  has_many :employee_time_off_policies
  has_many :time_off_policies, through: :employee_time_off_policies
  has_many :time_off_categories, through: :employee_balances
  has_many :employee_working_places
  has_many :working_places, through: :employee_working_places
  has_many :employee_presence_policies
  has_many :presence_policies, through: :employee_presence_policies
  has_many :registered_working_times

  validate :hired_event_presence, on: :create

  scope(:active_by_account, lambda do |account_id|
    where(account_id: account_id)
  end)

  scope(:active_user_by_account, lambda do |account_id|
    active_by_account(account_id).where('account_user_id IS NOT NULL')
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

  def self.active_employee_ratio_per_account(account_id)
    active_employee_count = Employee.active_by_account(account_id).count
    return if active_employee_count.zero?
    active_user_count = Employee.active_user_by_account(account_id).count
    ((active_user_count * 100.0) / active_employee_count).round(2)
  end

  def first_employee_working_place
    return unless employee_working_places.present?
    employee_working_places.find_by(effective_at: employee_working_places.pluck(:effective_at).min)
  end

  def civil_status_for(date = Time.zone.today)
    civil_status_event = last_civil_status_event_for(date)
    return 'single' unless civil_status_event
    CIVIL_STATUS[civil_status_event.event_type]
  end

  def civil_status_date_for(date = Time.zone.today)
    last_civil_status_event_for(date).try(:effective_at)
  end

  def first_employee_event
    events.find_by(event_type: 'hired') || events.find { |event| event.event_type.eql?('hired' ) }
  end

  def hired_date
    first_employee_event.try(:effective_at)
  end

  def active_policy_in_category_at_date(category_id, date = Time.zone.today)
    assigned_time_off_policies_in_category(category_id, date).first
  end

  def active_working_place_at(date = Time.zone.today)
    WorkingPlace.active_for_employee(id, date)
  end

  def last_balance_in_category(category_id)
    employee_balances.where(time_off_category_id: category_id).order('effective_at').last
  end

  def unique_balances_categories
    time_off_categories.distinct
  end

  def assigned_time_off_policies_in_category(category_id, date = Time.zone.today)
    EmployeeTimeOffPolicy.assigned_at(date).by_employee_in_category(id, category_id).limit(3)
  end

  def not_assigned_time_off_policies_in_category(category_id, date = Time.zone.today)
    EmployeeTimeOffPolicy.not_assigned_at(date).by_employee_in_category(id, category_id).limit(2)
  end

  def file_with?(file_id)
    employee_file_ids.include?(file_id)
  end

  def employee_files
    EmployeeFile.where(id: employee_file_ids)
  end

  def total_amount_of_data
    employee_attribute_versions
      .where("data -> 'attribute_type' = 'File'")
      .sum("(data -> 'size')::float") / 1024.0
  end

  def number_of_files
    employee_attribute_versions.where("data -> 'attribute_type' = 'File'").count
  end

  private

  def employee_file_ids
    employee_attribute_versions
      .where("data -> 'attribute_type' = 'File'")
      .pluck("data -> 'id'")
  end

  def hired_event_presence
    return if events && events.map(&:event_type).include?('hired')
    errors.add(:events, 'Employee must have hired event')
  end

  def last_civil_status_event_for(date)
    @last_civil_status_event_for ||=
      events
      .where('event_type IN (?) AND effective_at <= ?',  CIVIL_STATUS.keys, date)
      .order(:effective_at).last
  end
end
