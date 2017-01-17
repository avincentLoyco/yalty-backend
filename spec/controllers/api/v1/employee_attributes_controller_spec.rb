require 'rails_helper'

RSpec.describe API::V1::EmployeeAttributesController, type: :controller do
  include_context 'shared_context_headers'
  include_context 'shared_context_timecop_helper'

  let(:employee) { create(:employee, account: Account.current) }
  let(:json_response) { JSON.parse(response.body) }

  describe '#GET /employees/:employee_id/attributes' do
    subject(:get_request) { get :show, params }
    let(:params) {{ employee_id: employee.id, date: effective_at }}

    let!(:firstname_definition) do
      create(:employee_attribute_definition, name: 'firstname',
        attribute_type: Attribute::String.attribute_type, account: account)
    end
    let!(:lastname_definition) do
      create(:employee_attribute_definition, name: 'lastname',
        attribute_type: Attribute::String.attribute_type, account: account)
    end

    before 'create attributes' do
      hired_event = employee.events.find_by(event_type: 'hired')
      UpdateEvent.new(
        {
          id: hired_event.id,
          effective_at: hired_event.effective_at,
          event_type: hired_event.event_type,
          employee: { id: employee.id }
        },
        [{attribute_name: 'firstname', value: 'James'}]
      ).call

      CreateEvent.new(
        { effective_at: 5.days.from_now, event_type: 'default', employee: { id: employee.id } },
        [{attribute_name: 'lastname', value: 'Howlett'}]
      ).call

      CreateEvent.new(
        { effective_at: 10.days.from_now, event_type: 'default', employee: { id: employee.id } },
        [{attribute_name: 'firstname', value: 'Logan'}]
      ).call
    end

    context 'today' do
      let(:effective_at) { Time.zone.now }

      before { get_request }

      it { expect(response.status).to eq(200) }
      it { expect(json_response.size).to eq(1) }
      it { expect(json_response.first['value']).to eq('James') }
    end

    context '6 days from now' do
      let(:effective_at) { 6.days.from_now }

      before { get_request }

      it { expect(response.status).to eq(200) }
      it { expect(json_response.size).to eq(2) }
      it { expect(json_response.map { |a| a['value'] }).to match_array(%w(James Howlett)) }
    end

    context '20 days from now' do
      let(:effective_at) { 20.days.from_now }

      before { get_request }

      it { expect(response.status).to eq(200) }
      it { expect(json_response.size).to eq(2) }
      it { expect(json_response.map { |a| a['value'] }).to match_array(%w(Logan Howlett)) }
    end

    context 'invalid date' do
      let(:error_message) { json_response.fetch('errors').first.fetch('messages').first }

      context 'wrong type' do
        let(:effective_at) { 'I do not look like a date, huh?' }

        before { get_request }

        it { expect(response.status).to eq(422) }
        it { expect(error_message).to eq('must be a date') }
      end

      context 'date missing' do
        let(:params) {{ employee_id: employee.id }}

        before { get_request }

        it { expect(response.status).to eq(422) }
        it { expect(error_message).to eq('is missing') }
      end
    end
  end
end
