require 'rails_helper'

RSpec.describe Export::GenerateSpreadsheets, type: :service do
  shared_examples 'Valid CSV' do
    it { expect(File.exist?(file_path)).to be true }
    it { expect(FileUtils.compare_file(file_path, fixture)).to be true }
  end

  let!(:folder_path) { Rails.application.config.file_upload_root_path }
  let(:file_path)    { folder_path.join(file_name) }
  let(:fixture)      { Rails.root.join('spec', 'fixtures', 'files', fixture_name) }

  let!(:employees) do
    ['22222222-2222-2222-2222-222222222222', '33333333-3333-3333-3333-333333333333'].map do |id|
      create(:employee, id: id)
    end
  end

  let!(:account) do
    create(:account, id: '11111111-1111-1111-1111-111111111111', employees: employees)
  end

  subject { described_class.new(account, folder_path).call }

  before { FileUtils.mkdir_p(folder_path) }

  context 'generates time_off csv file' do
    let(:file_name) { 'time_offs.csv' }

    context 'without time offs' do
      let(:fixture_name) { 'empty_time_offs_test.csv' }

      before { subject }

      it_behaves_like 'Valid CSV'
    end

    context 'with time offs' do
      let(:fixture_name)      { 'time_offs_test.csv' }

      let(:sickness_category) { account.time_off_categories.find_by(name: 'sickness') }
      let(:accident_category) { account.time_off_categories.find_by(name: 'accident') }
      let(:start_time)        { '2017-04-01 15:00:00'.to_datetime }
      let(:end_time)          { '2017-04-03 03:00:00'.to_datetime }
      let!(:sickness_time_off) do
        create(:time_off,
          employee: employees.first, time_off_category: sickness_category, start_time: start_time,
          end_time: end_time)
      end
      let!(:accident_time_off) do
        create(:time_off,
          employee: employees.second, time_off_category: accident_category, start_time: start_time,
          end_time: end_time)
      end

      before { subject }

      it_behaves_like 'Valid CSV'
    end
  end

  context 'generates working_hours csv file' do
    let(:file_name) { 'working_hours.csv' }

    context 'with no registered working times' do
      let(:fixture_name) { 'empty_working_hours_test.csv' }
      before { subject }

      it_behaves_like 'Valid CSV'
    end

    context 'with registered working time' do
      let(:fixture_name) { 'working_hours_test.csv' }

      before do
        create(:registered_working_time, employee: employees.first)
        create(:registered_working_time,
          date: '6/6/2016', comment: 'asd', employee: employees.second)
        subject
      end

      it_behaves_like 'Valid CSV'
    end

    context 'with registered working time that has more time entries' do
      let(:fixture_name)  { 'working_hours_test2.csv' }

      let!(:working_time) { create(:registered_working_time, employee: employees.first) }
      let!(:second_working_time) do
        create(:registered_working_time,
          date: '6/6/2016', comment: 'asd', employee: employees.second,
          time_entries: [{ start_time: '8:00:00', end_time: '10:00:00' }])
      end

      before { subject }

      it_behaves_like 'Valid CSV'
    end
  end

  context 'generates employees csv file' do
    let(:file_name) { 'employees.csv' }

    context 'without employees' do
      let(:fixture_name) { 'empty_employees_test.csv' }
      let(:employees)    { [] }
      before { subject }

      it_behaves_like 'Valid CSV'
    end

    context 'with employees that have only hired and contract end events' do
      let(:fixture_name) { 'hired_employee_test.csv' }
      let!(:contract_end) do
        create(:employee_event,
          effective_at: '06-06-2016'.to_date, event_type: 'contract_end',
          employee: employees.second)
      end

      before do
        employees.first.events
                 .find_by(event_type: 'hired')
                 .update(effective_at: '06-06-2015'.to_date)
        employees.second.events
                 .find_by(event_type: 'hired')
                 .update(effective_at: '06-06-2014'.to_date)
        subject
      end

      it_behaves_like 'Valid CSV'
    end

    context 'with one employee attribute versions' do
      let(:fixture_name) { 'one_employees_test.csv' }
      let!(:employee)    { create(:employee, id: '22222222-2222-2222-2222-222222222222') }
      let(:employees)    { [employee] }

      let!(:change_event) do
        create(:employee_event,
          effective_at: '06-06-2015'.to_date, event_type: 'change', employee: employees.first)
      end

      let(:firstname_definition) do
        account.employee_attribute_definitions.find_by(name: 'firstname')
      end

      let(:lastname_definition) do
        account.employee_attribute_definitions.find_by(name: 'lastname')
      end

      let!(:firstname_attribute) do
        create(:employee_attribute,
          employee: employees.first, event: change_event,
          attribute_definition: firstname_definition, value: 'Jim')
      end
      let!(:lastname_attribute) do
        create(:employee_attribute,
          employee: employees.first, event: change_event,
          attribute_definition: lastname_definition, value: 'Moriarty')
      end

      before do
        employees.first.events
                 .find_by(event_type: 'hired')
                 .update(effective_at: '06-06-2015'.to_date)
        subject
      end

      it_behaves_like 'Valid CSV'
    end

    context 'with different attribute versions' do
      let!(:change_event) do
        create(:employee_event,
          effective_at: '06-06-2015'.to_date, event_type: 'change', employee: employees.first)
      end

      let!(:change_event2) do
        create(:employee_event,
          effective_at: '07-06-2015'.to_date, event_type: 'change', employee: employees.second)
      end

      let!(:contract_end) do
        create(:employee_event,
          effective_at: '06-06-2016'.to_date, event_type: 'contract_end',
          employee: employees.second)
      end

      let(:firstname_definition) do
        account.employee_attribute_definitions.find_by(name: 'firstname')
      end

      let(:lastname_definition) do
        account.employee_attribute_definitions.find_by(name: 'lastname')
      end

      let!(:tax_source_code) do
        create(:employee_attribute_definition,
          :system, account: account, name: 'tax_source_code',
                   attribute_type: Attribute::Number.attribute_type)
      end

      let!(:address) do
        create(:employee_attribute_definition,
          :system, account: account, name: 'address',
                   attribute_type: Attribute::String.attribute_type)
      end

      let!(:person) do
        create(:employee_attribute_definition,
          :system, account: account, name: 'person_attribute',
                   attribute_type: Attribute::Person.attribute_type)
      end

      before do
        [
          { name: 'Jim',      employee: employees.first },
          { name: 'Sherlock', employee: employees.second }
        ].each do |firstname_attr|
          create(:employee_attribute,
            employee: firstname_attr[:employee], event: change_event,
            attribute_definition: firstname_definition, value: firstname_attr[:name])
        end

        [
          { name: 'Moriarty', employee: employees.first },
          { name: 'Holmes',   employee: employees.second }
        ].each do |lastname_attr|
          create(:employee_attribute,
            employee: lastname_attr[:employee], event: change_event,
            attribute_definition: lastname_definition, value: lastname_attr[:name])
        end

        employees.first.events
                 .find_by(event_type: 'hired')
                 .update(effective_at: '06-06-2015'.to_date)
        employees.second.events
                 .find_by(event_type: 'hired')
                 .update(effective_at: '04-06-2015'.to_date)
      end

      context 'without hash attributes' do
        let(:fixture_name) { 'different_attributes_employee_test.csv' }
        let!(:tax_attribute) do
          create(:employee_attribute,
            employee: employees.second, event: change_event, attribute_definition: tax_source_code,
            value: 666_666)
        end

        let!(:address_attribute) do
          create(:employee_attribute,
            employee: employees.first, event: change_event, attribute_definition: address,
            value: 'Baker Street')
        end

        before { subject }

        it_behaves_like 'Valid CSV'
      end

      context 'with hash attributes' do
        let(:fixture_name) { 'hash_attributes_employee_test.csv' }
        let!(:wife) do
          create(:employee_attribute,
            employee: employees.first, event: change_event, attribute_definition: person,
            value: { lastname:      'Adler',                  firstname:   'Irene',
                     birthdate:     '06-06-1993'.to_datetime, gender:      'female',
                     nationality:   'English',                permit_type: 'permit',
                     permit_expiry: '06-06-2000'.to_datetime, avs_number:  'avs' })
        end
        before { subject }

        it_behaves_like 'Valid CSV'
      end
    end
  end
end
