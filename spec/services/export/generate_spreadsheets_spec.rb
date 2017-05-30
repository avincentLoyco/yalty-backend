require 'rails_helper'

RSpec.describe Export::GenerateSpreadsheets, type: :service do
  include_context 'shared_context_spreadsheets'
  subject { described_class.new(account, folder_path).call }

  it 'generates all files' do
    expect { subject }
      .to change { Dir.entries(folder_path).select { |file| !File.directory? file }.count }
      .from(0)
      .to(3)
  end

  context 'generates proper files' do
    before { subject }

    it do
      expect(Dir.entries(folder_path).select { |file| !File.directory? file })
        .to include('employees.csv', 'time_offs.csv', 'working_hours.csv')
    end
  end
end
