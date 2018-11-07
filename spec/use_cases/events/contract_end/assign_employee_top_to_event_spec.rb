require "rails_helper"

RSpec.describe Events::ContractEnd::AssignEmployeeTopToEvent do
  describe "#call" do
    subject { described_class.new(find_vacation_category: find_vacation_category_mock).call(event) }

    let(:event)        { build(:employee_event) }
    let(:vacation_toc) { build(:time_off_category) }

    let(:find_vacation_category_mock) do
      instance_double(TimeOffCategories::FindByName, call: vacation_toc)
    end

    # rubocop:disable RSpec/VerifiedDoubles
    let(:assigned_time_off_policies_in_category_mock) do
      double(order: [employee_time_off_policy])
    end
    # rubocop:enable RSpec/VerifiedDoubles

    let(:employee_time_off_policy) { build(:employee_time_off_policy) }

    before do
      allow(event.employee).to receive(:assigned_time_off_policies_in_category).and_return(
        assigned_time_off_policies_in_category_mock
      )
      allow(event).to receive(:save!).and_return(event)
      subject
    end

    it { expect(find_vacation_category_mock).to have_received(:call).with("vacation") }
    it { expect(event.employee_time_off_policy).to eq(employee_time_off_policy) }
    it { expect(event).to have_received(:save!) }
  end
end
