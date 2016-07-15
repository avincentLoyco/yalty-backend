class AddDayWithOrderSevenToPresencePolicies < ActiveRecord::Migration
  def change
    PresencePolicy.all.each do |presence_policy|
      next if presence_policy.presence_days.where(order: 7).present?
      presence_policy.presence_days.create!(order: 7)
    end
  end
end
