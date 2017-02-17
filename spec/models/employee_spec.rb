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
  it { is_expected.to have_many(:presence_policies) }
  it { is_expected.to have_many(:registered_working_times) }

  context 'scopes' do
    let(:account) { create(:account) }
    let(:employee) { create(:employee, account: account) }
    let!(:account_user) { create(:account_user, account: account, employee: employee) }

    before 'create employees' do
      create_list(:employee, 3, account: account)
      create_list(:employee, 3)
    end

    context '.active_by_account' do
      subject(:active_by_account_scope) { described_class.active_by_account(account.id) }

      it 'returns only employees with users / active employees' do
        expect(active_by_account_scope.count).to eq(4)
        expect(active_by_account_scope).to include(employee)
      end
    end

    context 'active_employee_ratio_per_account' do
      subject(:active_employee_ratio) do
        described_class.active_employee_ratio_per_account(account.id)
      end

      it 'returns proper ratio' do
        expect(active_employee_ratio).to eq(25.00)
      end
    end
  end

  context 'callbacks' do
    context '.trigger_intercom_update' do
      let!(:account) { create(:account) }
      let(:employee) { build(:employee, account: account) }

      it 'should invoke trigger_intercom_update on account' do
        expect(employee).to receive(:trigger_intercom_update)
        employee.save!
      end

      it 'should trigger create_or_update_on_intercom on account' do
        expect(account).to receive(:create_or_update_on_intercom).with(true)
        employee.save!
      end

      context 'with user' do
        let!(:user) { create(:account_user, account: account) }
        let!(:employee) { build(:employee, account: account, user: user) }

        it 'should trigger intercom update on user' do
          expect(user).to receive(:create_or_update_on_intercom).with(true)
          employee.save!
        end
      end

      context 'without user' do
        it 'should not trigger intercom update on user' do
          expect_any_instance_of(Account::User)
            .not_to receive(:create_or_update_on_intercom).with(true)
          employee.save!
        end
      end
    end
  end

  context 'methods' do
    let(:employee) { create(:employee) }

    context 'for employee_files' do
      let(:employee_files) { create_list(:employee_file, 2, :with_jpg) }
      let!(:employee_attributes) do
        employee_files.each do |file|
          create(:employee_attribute, employee: employee, attribute_type: 'File', data: {
            id: file.id,
            size: file.file_file_size,
            file_type: file.file_content_type,
            file_sha: '123'
          })
        end
      end
      let(:total_amount_of_data) { employee_files.sum(&:file_file_size) / 1024.0 }

      it { expect(employee.total_amount_of_data).to eq(total_amount_of_data) }
      it { expect(employee.number_of_files).to eq(2) }
    end

    context 'civil status' do
      context 'when employee has civil status changes' do
        include_context 'shared_context_timecop_helper'
        before { employee.reload.events }

        let!(:wedding_event) do
          create(:employee_event,
            effective_at: 1.year.ago, employee: employee, event_type: 'marriage')
        end
        let!(:divorce_event) do
          create(:employee_event,
            effective_at: Time.zone.today, employee: employee, event_type: 'divorce')
        end

        context 'and date param is not given' do
          it { expect(employee.civil_status_for).to eq 'divorced' }
          it { expect(employee.civil_status_date_for).to eq divorce_event.effective_at }
        end

        context 'and date param is given' do
          it { expect(employee.civil_status_for(5.months.ago)).to eq 'married' }
          it do
            expect(employee.civil_status_date_for(5.months.ago)).to eq wedding_event.effective_at
          end
        end
      end

      context 'when employee does not have civil status changes' do
        it { expect(employee.civil_status_for).to eq 'single' }
        it { expect(employee.civil_status_date_for).to eq nil }
      end
    end
  end
end
