require 'rails_helper'

RSpec.describe Employee::AttributeVersion, type: :model do
  subject! { build(:employee_attribute) }

  it { is_expected.to have_db_column(:data) }

  it { is_expected.to have_db_column(:employee_id).of_type(:uuid) }
  it { is_expected.to have_db_index(:employee_id) }
  it { is_expected.to belong_to(:employee).inverse_of(:employee_attribute_versions) }
  it { is_expected.to validate_presence_of(:employee) }

  it { is_expected.to have_one(:account).through(:employee) }

  it { is_expected.to have_db_column(:attribute_definition_id) }

  it { is_expected.to belong_to(:event).class_name('Employee::Event') }
  it { is_expected.to validate_presence_of(:event) }

  it { is_expected.to_not validate_presence_of(:order) }
  it { expect { subject.valid? }.to_not change { subject.errors.messages[:order] } }

  it 'should delegate effective_at to event' do
    is_expected.to respond_to(:effective_at)
    expect(subject.effective_at).to eq(subject.event.effective_at)
  end

  context 'order presence validation' do
    let(:definition) { create(:employee_attribute_definition, multiple: true) }
    subject {
      build(:employee_attribute, attribute_definition: definition, order: nil, multiple: true)
    }

    it { is_expected.to validate_presence_of(:order) }
    it { expect(subject.valid?).to eq false }
    it { expect { subject.valid? }.to change { subject.errors.messages[:order] } }
  end

  context '#value_presence validation' do
    subject { build(:employee_attribute_version, attribute_definition: attribute_definition ) }

    context 'when attribute is required' do
      let!(:attribute_definition) do
        create(:employee_attribute_definition, :required, attribute_type: "String")
      end

      it { expect(subject.valid?).to eq false }
      it { expect { subject.valid? }.to change { subject.data.errors.messages[:string] } }

      context 'when attribute has more than one key' do
        let!(:attribute_definition) do
          create(:employee_attribute_definition, :required, attribute_type: 'File', name: 'File')
        end

        subject do
          build(:employee_attribute,
            attribute_type: 'File', attribute_definition: attribute_definition, data: data)
        end

        context 'and all attributes values not given' do
          let(:data) { {} }

          it { expect(subject.valid?).to eq false }
          [:size, :id, :file_type].map do |attribute|
            it do
              expect { subject.valid? }.to change { subject.data.errors.messages[attribute] }
                .to include "can't be blank"
            end
          end
        end

        context 'when one attribute value not given' do
          let(:data) {{ size: 1000, file_type: 'jpg' }}

          it { expect(subject.valid?).to eq false }
          it do
            expect { subject.valid? }.to change { subject.data.errors.messages[:id] }
              .to include "can't be blank"
          end
        end

        context 'and all attribute values given' do
          let(:data) {{ size: 1000, file_type: 'jpg', id: '12345' }}

          it { expect(subject.valid?).to eq true }
          it { expect { subject.valid? }.to_not change { subject.data.errors.messages } }
        end
      end
    end

    context 'when attribute is not required' do
      let!(:attribute_definition) do
        create(:employee_attribute_definition, attribute_type: "String")
      end

      it { expect(subject.valid?).to eq true }
      it { expect { subject.valid? }.to_not change { subject.data.errors.messages[:string] } }
    end
  end
end
