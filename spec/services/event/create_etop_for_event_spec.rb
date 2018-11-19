require "rails_helper"

RSpec.describe CreateEtopForEvent do
  include_context "shared_context_account_helper"

  let!(:effective_at) { Date.new(2017, 5, 1) }
  let(:event_type) { "hired" }
  let(:event) do
    create(:employee_event,
      effective_at: effective_at,
      event_type: event_type)
  end
  let(:employee) { event.employee }
  let!(:vacation_category) { create(:time_off_category, account: employee.account, name: "vacation") }
  let!(:presence_policy) do
    create(:presence_policy, :with_time_entries, account: employee.account, occupation_rate: 0.8)
  end
  let(:employee_id) { employee.id }
  let(:time_off_policy_amount) { 9600 }
  let!(:occupation_rate_definition) do
    create(:employee_attribute_definition,
           name: "occupation_rate",
           account: employee.account,
           attribute_type: Attribute::Number.attribute_type,
           validation: { range: [0, 1] }
          )
  end
  let!(:employee_attribute) do
    create(:employee_attribute, event: event, employee: employee,
      attribute_definition: occupation_rate_definition, value: 0.8)
  end

  subject { described_class.new(event.id, time_off_policy_amount).call }

  shared_examples "there is no time off policy" do
    it { expect { subject }.to change(TimeOffPolicy.where(time_off_category_id:
      vacation_category.id), :count).by(1) }
    it { expect { subject }.to change(EmployeeTimeOffPolicy.where(time_off_category_id:
      vacation_category.id), :count).by(1) }
    it do
      subject
      expect(event.employee_time_off_policy).not_to be(nil)
    end
  end

  shared_examples "time off policy exists" do
    before do
      create(:time_off_policy,
        time_off_category_id: vacation_category.id,
        start_month: 1,
        start_day: 1,
        end_day: nil,
        end_month: nil,
        amount: time_off_policy_amount)
    end
    it { expect { subject }.to change(TimeOffPolicy.where(time_off_category_id:
      vacation_category.id), :count).by(0) }
    it { expect { subject }.to change(EmployeeTimeOffPolicy.where(time_off_category_id:
      vacation_category.id), :count).by(1) }
    it do
      subject
      expect(event.employee_time_off_policy).not_to be(nil)
    end
  end

  context "when hired event happens" do
    context "and time off policy of given amount does not exist" do
      it_behaves_like "there is no time off policy"
    end
    context "and time off policy of given amount already exists" do
      it_behaves_like "time off policy exists"
    end
  end
  context "when work contract event happens" do
    let(:event_type) { "work_contract" }
    context "and time off policy of given amount does not exist" do
      it_behaves_like "there is no time off policy"
    end
    context "and time off policy of given amount does exist" do
      it_behaves_like "time off policy exists"
    end
  end
end
