# frozen_string_literal: true

require "rails_helper"

RSpec.describe Employees::FindUnassignedTopsForEmployee do
  context "#call" do
    subject { described_class.new.call(employee) }

    let_it_be(:account) { create(:account) }
    let_it_be(:custom_category) { create(:time_off_category, system: false, account: account) }
    let_it_be(:default_categories) { account.time_off_categories.where(system: true) }
    let_it_be(:vacation_category) { default_categories.vacation.first }
    let_it_be(:sickness_category) { default_categories.sickness.first }

    let_it_be(:top_20) do
      create(:time_off_policy, policy_type: "balancer", time_off_category: vacation_category,
        amount: 9600)
    end
    let_it_be(:top_26) do
      create(:time_off_policy, policy_type: "balancer", time_off_category: vacation_category,
        amount: 12480)
    end
    let_it_be(:custom_top) do
      create(:time_off_policy, policy_type: "counter", time_off_category: custom_category)
    end
    let_it_be(:default_top) do
      create(:time_off_policy, policy_type: "counter", time_off_category: sickness_category)
    end

    let_it_be(:employee) { create(:employee, account: account) }

    before { create(:employee_time_off_policy, employee: employee, time_off_policy: top_20) }

    context "when employee is assigned only to one balancer top" do
      it { expect(subject).to match_array([default_top, custom_top]) }
    end

    context "when employee is already assigned to some of the counter tops" do
      before { create(:employee_time_off_policy, employee: employee, time_off_policy: default_top) }

      it { expect(subject).to match_array([custom_top]) }
    end
  end
end
