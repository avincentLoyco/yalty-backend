class GenerateReferrersForAllUsers < ActiveRecord::Migration
  def up
    Account::User.pluck(:email).uniq.each do |email|
      next if Referrer.where(email: email).exists?
      Referrer.create!(email: email)
    end
  end
end
