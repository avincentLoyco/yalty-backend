RSpec.shared_context 'shared_context_join_tables_effective_at' do |settings|
  include_context 'shared_context_account_helper'

  let(:employee) { create(:employee) }
  before do
    create(:employee_event,
      employee: employee, effective_at: Date.new(2014, 1, 1), event_type: 'contract_end'
    )
    employee.events.reload
  end

  subject { build(settings[:join_table], employee: employee, effective_at: effective_at) }

  describe 'effective_at_cannot_be_before_hired_date' do
    let(:effective_at) { employee.hired_date - 10.days }

    it { expect(subject.valid?).to eq false }
    it do
      expect { subject.valid? }.to change { subject.errors.messages[:effective_at] }
        .to include 'can\'t be set before employee hired date'
    end
  end

  describe 'effective_at_between_hired_date_and_contract_end' do
    context 'when employee has one hired event and one contract end' do
      context 'with valid params' do
        let(:effective_at) { Date.new(2012, 1, 1) }

        it { expect(subject.valid?).to eq true }
        it { expect { subject.valid? }.to_not change { subject.errors.messages.count } }
      end

      context 'with invalid params' do
        let(:effective_at) { Date.new(2014, 2, 1) }

        it { expect(subject.valid?).to eq false }
        it do
          expect { subject.valid? }.to change { subject.errors.messages[:effective_at] }
            .to include 'can\'t be set after employee contract end date'
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
              .to include 'can\'t be set after employee contract end date'
          end
        end

        context 'effective at after new contract end date' do
          let(:effective_at) { Date.new(2016, 1, 1) }

          it { expect(subject.valid?).to eq false }
          it do
            expect { subject.valid? }.to change { subject.errors.messages[:effective_at] }
              .to include 'can\'t be set after employee contract end date'
          end
        end
      end
    end
  end
end
