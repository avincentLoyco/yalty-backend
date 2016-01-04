class TimeOffCategory < ActiveRecord::Base
  DEFAULT = %w(sickness)

  belongs_to :account
  has_many :time_offs

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
