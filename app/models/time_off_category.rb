class TimeOffCategory < ActiveRecord::Base
  DEFAULT = %w(sickness vacation accident maternity civil_service other).freeze

  belongs_to :account
  has_many :time_offs
  has_many :time_off_policies
  has_many :employee_balances, class_name: 'Employee::Balance'
  has_many :time_off_policies

  validates :account, :name, presence: true
  validates :name, uniqueness: { scope: :account }

  scope :editable, -> { where(system: false) }

  def self.update_default_account_categories(account)
    TimeOffCategory::DEFAULT.each do |category|
      time_off_category = account.time_off_categories.where(name: category).first

      if time_off_category.nil?
        time_off_category = account.time_off_categories.build(
          name: category,
          system: true
        )
      end

      time_off_category.save
    end
  end
end
