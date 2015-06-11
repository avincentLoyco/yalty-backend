require 'rails_helper'

RSpec.describe Employee, type: :model do
  it { is_expected.to have_db_column(:uuid) }
  it { is_expected.to have_readonly_attribute(:uuid) }

  it 'should generate uuid on create' do
    employee = FactoryGirl.create(:employee, uuid: nil)

    employee.reload

    expect(employee.uuid).to_not be_nil
  end

  it { is_expected.to have_db_column(:account_id) }
  it { is_expected.to have_db_index(:account_id) }
  it { is_expected.to belong_to(:account).inverse_of(:employees) }

  it { is_expected.to have_many(:employee_attributes).inverse_of(:employee) }
end
