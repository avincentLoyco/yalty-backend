require 'rails_helper'
require 'rake'

RSpec.describe 'add_active_attr_to_events', type: :rake do
  include_context 'rake'

  let(:created_at_date) { Date.new(2017, 2, 1) }
  let(:employee) { create(:employee, created_at: created_at_date) }

  let(:event_created_at_date) { Date.new(2017, 2, 1) }
  let(:event_type) { 'hired' }
  let(:event) do
    create(:employee_event,
      event_type: event_type,
      employee: employee,
      created_at: event_created_at_date)
  end

  shared_examples 'omitting update' do
    it 'omits update' do
      subject
      expect(event).to_not receive(:update_attribute)
    end
  end

  shared_examples 'sets event inactive' do
    it 'updates event to inactive' do
      expect{ subject }.to change { event.reload.active }.from(true).to(false)
    end
  end

  context 'events created in 2018' do
    describe 'hired event' do
      before { employee.events.delete_all }
      let(:created_at_date) { Date.new(2018, 2, 1) }
      let(:event_created_at_date) { Date.new(2018, 2, 1) }

      it_behaves_like 'omitting update'
    end

    describe 'work contract event' do
      let(:created_at_date) { Date.new(2018, 2, 1) }
      let(:event_created_at_date) { Date.new(2018, 3, 1) }
      let(:event_type) { 'work_contract' }

      it_behaves_like 'omitting update'
    end

    describe 'contract end event' do
      let(:created_at_date) { Date.new(2018, 2, 1) }
      let(:event_created_at_date) { Date.new(2018, 3, 1) }
      let(:event_type) { 'contract_end' }

      it_behaves_like 'omitting update'
    end
  end

  context 'events created before 2018' do
    describe 'hired event' do
      before { employee.events.delete_all }
      let(:created_at_date) { Date.new(2017, 2, 1) }
      let(:event_created_at_date) { Date.new(2017, 2, 1) }

      it_behaves_like 'sets event inactive'
    end

    describe 'work contract event' do
      let(:created_at_date) { Date.new(2017, 2, 1) }
      let(:event_created_at_date) { Date.new(2017, 3, 1) }
      let(:event_type) { 'work_contract' }

      it_behaves_like 'sets event inactive'
    end

    describe 'contract end event' do
      let(:created_at_date) { Date.new(2017, 2, 1) }
      let(:event_created_at_date) { Date.new(2017, 3, 1) }
      let(:event_type) { 'contract_end' }

      it_behaves_like 'sets event inactive'
    end
  end
end
