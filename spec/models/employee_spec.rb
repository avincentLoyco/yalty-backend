require 'rails_helper'

RSpec.describe Employee, type: :model do
  include_context 'shared_context_account_helper'
  it { is_expected.to have_db_column(:account_id).of_type(:uuid) }
  it { is_expected.to belong_to(:account).inverse_of(:employees) }
  it { is_expected.to respond_to(:account) }
  it { is_expected.to validate_presence_of(:account) }

  it { is_expected.to have_many(:employee_attribute_versions).inverse_of(:employee) }
  it { is_expected.to have_many(:time_offs) }
  it { is_expected.to have_many(:employee_working_places) }
  it { is_expected.to have_many(:employee_balances) }

  it { is_expected.to have_many(:employee_attributes).inverse_of(:employee) }

  it { is_expected.to have_many(:events).inverse_of(:employee) }
  it { is_expected.to belong_to(:presence_policy) }
  it { is_expected.to belong_to(:holiday_policy) }

  context 'employee working places presence' do
    let(:employee) { build(:employee) }
    subject { employee }

    context 'with employee working place' do
      it { expect(subject.valid?).to eq true }
      it { expect { subject.valid? }.to_not change { subject.errors.messages.count } }
    end

    context 'without employee working place' do
      before { employee.employee_working_places = [] }

      it { expect(subject.valid?).to eq false }
      it { expect { subject.valid? }
        .to change { subject.errors.messages[:employee_working_places] } }
    end
  end
end
