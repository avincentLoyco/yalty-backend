RSpec.shared_context 'shared_context_join_tables_effective_at' do |settings|
  include_context 'shared_context_account_helper'

  let(:first_time_hired_at) { Date.new(2012, 1, 1) }
  let(:first_contract_end_at) { Date.new(2014, 1, 1) }
  let(:employee) { create(:employee, hired_at: first_time_hired_at, contract_end_at: first_contract_end_at) }
  before { employee.events.reload }

  subject { build(settings[:join_table], employee: employee, effective_at: effective_at) }

  describe 'effective at cannot be before hired date' do
    let(:effective_at) { first_time_hired_at - 10.days }

    it { expect(subject.valid?).to eq false }
    it do
      expect { subject.valid? }.to change { subject.errors.messages[:effective_at] }
        .to include 'can\'t be set outside of employee contract period'
    end
  end

  describe 'reset_join_table_effective_at_after_contract_end' do
    let(:effective_at) { employee.hired_date + 10.days }

    context 'when join table does not have reset resource assigned' do
      it { expect(subject.valid?).to eq true }
      it { expect { subject.valid? }.to_not change { subject.errors.messages.size } }
    end

    context 'when join table has reset resource assigned' do
      before { subject.related_resource.update!(reset: true) }

      context 'and it has proper effective at' do
        let(:effective_at) { Date.new(2014, 1, 1) + 1.day }

        it { expect(subject.valid?).to eq true }
        it { expect { subject.valid? }.to_not change { subject.errors.messages.size } }
      end

      context 'and it does not have proper effective at' do
        it { expect(subject.valid?).to eq false }
        it do
          expect { subject.valid? }.to change { subject.errors.messages[:effective_at] }
            .to include 'must be set up day after employee contract end date'
        end
      end
    end
  end

  describe 'effective at cannot be after contract end date' do
    context 'when employee has one hired event and one contract end' do
      context 'with valid params' do
        let(:effective_at) { first_contract_end_at - 10.days }

        it { expect(subject.valid?).to eq true }
        it { expect { subject.valid? }.to_not change { subject.errors.messages.count } }
      end

      context 'with invalid params' do
        let(:effective_at) { first_contract_end_at + 10.days }

        it { expect(subject.valid?).to eq false }
        it do
          expect { subject.valid? }.to change { subject.errors.messages[:effective_at] }
            .to include 'can\'t be set outside of employee contract period'
        end
      end
    end

    context 'when employee has more than one hired event and contract end dates' do
      before do
        create(:employee_event,
          employee: employee, effective_at: Date.new(2015, 1, 1), event_type: 'hired'
        )
        create(:employee_event,
          employee: employee, effective_at: Date.new(2016, 1, 1), event_type: 'contract_end'
        )
        employee.events.reload
      end

      context 'with valid params' do
        let(:effective_at) { Date.new(2015, 1, 1) }

        it { expect(subject.valid?).to eq true }
        it { expect { subject.valid? }.to_not change { subject.errors.messages.count } }
      end

      context 'with invalid params' do
        context 'effective at between old contract end date and new hired date' do
          let(:effective_at) { Date.new(2014, 1, 1) }

          it { expect(subject.valid?).to eq false }
          it do
            expect { subject.valid? }.to change { subject.errors.messages[:effective_at] }
              .to include 'can\'t be set outside of employee contract period'
          end
        end

        context 'effective at after new contract end date' do
          let(:effective_at) { Date.new(2016, 1, 1) }

          it { expect(subject.valid?).to eq false }
          it do
            expect { subject.valid? }.to change { subject.errors.messages[:effective_at] }
              .to include 'can\'t be set outside of employee contract period'
          end
        end
      end
    end
  end
end
