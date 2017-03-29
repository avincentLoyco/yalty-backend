require 'rails_helper'

RSpec.describe UpdateEventAttributeValidator, type: :service do
  let(:user) { create(:account_user, role: 'user') }
  let(:account) { user.account }
  let(:hired_event) do
    create(:employee_event, event_type: 'hired', effective_at: 2.days.from_now.at_beginning_of_day)
  end

  let(:profile_picture) { create :employee_file, :with_jpg }
  let!(:employee) do
    create(:employee, :with_attributes,
      account: account,
      account_user_id: user.id,
      events: [hired_event],
      employee_attributes: {
        firstname: employee_first_name,
        annual_salary: employee_annual_salary
      }
    )
  end
  let(:employee_id) { employee.id }
  let(:employee_first_name) { 'John' }
  let(:employee_annual_salary) { '2000' }

  let!(:event) { employee.events.where(event_type: 'hired').first! }

  let(:first_name_attribute_definition) { 'firstname' }
  let(:first_name_attribute_id) { first_name_attribute.id }
  let(:first_name_attribute) do
    event.employee_attribute_versions.find do |attr|
      attr.attribute_name == 'firstname'
    end
  end
  let(:new_first_name_value) { 'Nicolas' }

  let(:annual_salary_attribute_definition) { 'annual_salary' }
  let(:annual_salary_attribute_id) { annual_salary_attribute.id }
  let(:annual_salary_attribute) do
    event.employee_attribute_versions.find do |attr|
      attr.attribute_name == 'annual_salary'
    end
  end
  let(:new_annual_salary_value) { employee_annual_salary }

  let!(:file_definition_name) { 'profile_picture' }
  let(:profile_picture_id) { profile_picture.id }

  let(:employee_attributes_payload) do
    [
      {
        id: first_name_attribute_id,
        value: new_first_name_value,
        attribute_name: first_name_attribute_definition
      },
      {
        type: 'profile_picture',
        value: profile_picture_id,
        attribute_name: file_definition_name
      },
      {
        id: annual_salary_attribute_id,
        value: new_annual_salary_value,
        attribute_name: annual_salary_attribute_definition
      }
    ]
  end

  describe '#call' do
    before do
      Account.current = account
      Account::User.current = user
    end

    subject { described_class.new(employee_attributes_payload).call }

    context 'when there are no unauthorized attributes being updated' do
      before { employee_attributes_payload.pop }

      it { expect { subject }.not_to raise_error }
    end

    context 'when an unauthorized attribute tries to be updated' do
      let(:new_annual_salary_value) { '5' }

      it { expect { subject }.to raise_error(CanCan::AccessDenied, 'Not authorized!') }
    end

    context 'when there is a new unauthorized attributes being added' do
      let(:annual_salary_attribute_id) { nil }

      it { expect { subject }.to raise_error(CanCan::AccessDenied, 'Not authorized!') }
    end

    context 'when the attribute trying to being added does not belong to the event' do
      let(:annual_salary_attribute_id) { "44070cae-0f86-456f-9b3d-17a801db64bf" }

      it { expect { subject }.to raise_error(CanCan::AccessDenied, 'Not authorized!') }
    end

    context 'when file value is nil' do
      before { employee_attributes_payload.pop }
      let(:profile_picture_id) { nil }

      it { expect { subject }.not_to raise_error }
    end

    context 'when file value is present' do
      before { employee_attributes_payload.pop }
      let(:profile_picture_id) { profile_picture.id }

      context 'when Account has filevault plan' do
        before { Account.current.update(available_modules: ['filevault']) }

        it { expect { subject }.not_to raise_error }
      end
      context "when Account doesn't have filevault plan" do
        before { Account.current.update(available_modules: []) }

        context 'when attribute type is profile picture' do
          it { expect { subject }.not_to raise_error }
        end

        context "when attribute type isn't profile picture" do
          let!(:file_definition_name) { 'contract' }

          it { expect { subject }.to raise_error(CanCan::AccessDenied, 'Not authorized!') }
        end
      end
    end
  end
end
