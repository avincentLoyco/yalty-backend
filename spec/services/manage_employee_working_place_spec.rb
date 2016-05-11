require 'rails_helper'

RSpec.describe ManageEmployeeWorkingPlace, type: :service do
  include_context 'shared_context_account_helper'
  subject { ManageEmployeeWorkingPlace.new(employee, effective_at).call }

  let(:employee) { create(:employee) }
  let!(:first_working_place) { employee.first_employee_working_place }

  context 'with valid effective at' do
    context 'when one working place in period' do
      context 'and employees only working place' do
        context 'and effective at moved to past' do
          let(:effective_at) { Time.now - 5.days }

          it { expect { subject }.to change { first_working_place.reload.effective_at } }
          it { expect { subject }.to_not change { EmployeeWorkingPlace.count } }
        end

        context 'and effective at moved to future' do
          let(:effective_at) { Time.now + 5.days }

          it { expect { subject }.to change { first_working_place.reload.effective_at } }
          it { expect { subject }.to_not change { EmployeeWorkingPlace.count } }
        end
      end

      context 'and employee has more employee working places but not in period' do
        let(:effective_at) { Time.now + 5.days }
        let!(:second_working_place) do
          create(:employee_working_place, employee: employee, effective_at: Time.now + 1.week)
        end

        it { expect { subject }.to change { first_working_place.reload.effective_at } }
        it { expect { subject }.to_not change { EmployeeWorkingPlace.count } }
      end
    end

    context 'when more working places in period' do
      let!(:second_working_place) do
        create(:employee_working_place, employee: employee, effective_at: Time.now + 1.week)
      end
      let!(:third_working_place) do
        create(:employee_working_place, employee: employee, effective_at: Time.now + 2.weeks)
      end

      context 'and effective at moved to past' do
        let(:effective_at) { Time.now - 5.days }

        it { expect { subject }.to change { first_working_place.reload.effective_at } }
        it { expect { subject }.to_not change { EmployeeWorkingPlace.count } }
      end

      context 'and effective at moved to future' do
        let(:effective_at) { Time.now + 3.weeks }

        it { expect { subject }.to change { third_working_place.reload.effective_at } }
        it { expect { subject }.to change { EmployeeWorkingPlace.count }.by(-2) }
        it { expect { subject }.to change { EmployeeWorkingPlace.exists?(second_working_place.id) } }
        it { expect { subject }.to change { EmployeeWorkingPlace.exists?(first_working_place.id) } }
      end
    end
  end

  context 'with invalid effective at' do
    let(:effective_at) { 'abc' }

    it { expect { subject }.to_not change { first_working_place.reload.effective_at } }
    it { expect { subject }.to_not change { EmployeeWorkingPlace.count } }
  end
end
