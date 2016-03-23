require 'rails_helper'

RSpec.describe UpdateEventAttributeValidator, type: :service do
  let(:user) { create(:account_user, account_manager: false) }
  let(:account) { user.account }
  let!(:employee) do
    create(:employee, :with_attributes,
      account: account,
      account_user_id: user.id,
      event: {
        event_type: 'hired',
        effective_at: 2.days.from_now.at_beginning_of_day
      },
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

  let(:first_name_attribute_definition) { 'firstname'}
  let(:first_name_attribute_id) { first_name_attribute.id }
  let(:first_name_attribute) do
    event.employee_attribute_versions.find do |attr|
      attr.attribute_name == 'firstname'
    end
  end
  let(:new_first_name_value) { 'Nicolas' }

  let(:annual_salary_attribute_definition) { 'annual_salary'}
  let(:annual_salary_attribute_id) { annual_salary_attribute.id }
  let(:annual_salary_attribute) do
    event.employee_attribute_versions.find do |attr|
      attr.attribute_name == 'annual_salary'
    end
  end
  let(:new_annual_salary_value) { employee_annual_salary }

  let(:employee_attributes_payload) do
    [
      { id: first_name_attribute_id,
        value: new_first_name_value,
        attribute_name: first_name_attribute_definition
      },
      { id: annual_salary_attribute_id,
        value: new_annual_salary_value,
        attribute_name: annual_salary_attribute_definition

      }
    ]
  end

  describe '#call' do
    subject { described_class.new(employee_attributes_payload, event).call }

    context 'when there are no unauthorized attributes being updated' do
      it {  expect { subject }.not_to raise_error }
      it {  expect { subject }.not_to raise_error(CanCan::AccessDenied, 'Not authorized!') }
    end

    context 'when an unauthorized attribute tries to be updated' do
      let(:new_annual_salary_value) { '5' }

      it {  expect { subject }.to raise_error(CanCan::AccessDenied, 'Not authorized!') }
    end

    context 'when there is a new unauthorized attributes being added' do
      let(:annual_salary_attribute_id) { nil }

      it {  expect { subject }.to raise_error(CanCan::AccessDenied, 'Not authorized!') }
    end

    context 'when the attribute trying to being added does not belong to the event' do
      let(:annual_salary_attribute_id) { "44070cae-0f86-456f-9b3d-17a801db64bf" }

      it {  expect { subject }.to raise_error(CanCan::AccessDenied, 'Not authorized!') }
    end
  end

end