require "rails_helper"

RSpec.describe FindValueForAttribute do
  include_context "shared_context_account_helper"
  include_context "shared_context_remove_original_helper"

  subject { FindValueForAttribute.new(attribute, version).call }

  let(:attribute) { { value: value } }
  let(:employee)  { create(:employee) }
  let(:version)   { Employee::AttributeVersion.new(attribute_definition: definition) }
  let(:definition) do
    create(:employee_attribute_definition,
      account: employee.account, attribute_type: attribute_type, name: attribute_name)
  end

  context "when attribute definition not present or definition is other than File type" do
    let(:value) { "Snow" }
    let(:attribute_type) { Attribute::String.attribute_type }
    let(:attribute_name) { "lastname" }

    it { expect(subject).to eq "Snow" }
    it { expect { subject }.to_not raise_error }

    context "when defintion not given" do
      let(:definition) { nil }

      it { expect(subject).to eq "Snow" }
      it { expect { subject }.to_not raise_error }
    end
  end

  context "when attribute definition is File type" do
    before { allow_any_instance_of(GenericFile).to receive(:find_file_path) { image_path } }

    let(:image_path) { ["#{Rails.root}/spec/fixtures/files/test.jpg"] }

    let(:attribute_type) { Attribute::File.attribute_type }
    let(:attribute_name) { "profile_picture" }
    let(:employee_file)  { create(:generic_file) }

    let(:value) { employee_file.id }
    let(:image) { File.open(File.join(image_path)) }

    it { expect(subject[:id]).to eq employee_file.id }
    it { expect(subject[:size]).to eq image.size }
    it { expect(subject[:file_type]).to eq MIME::Types.type_for(image_path).first.content_type }
    it { expect(subject[:original_sha]).to eq Digest::SHA256.file(image_path.first).hexdigest }

    it { expect { subject }.to_not raise_error }

    context "when file with given id does not exist" do
      let(:value) { "123" }

      it { expect { subject }.to raise_error(ActiveRecord::RecordNotFound) }
    end

    context "when number of files in directory is different than 1" do
      context "should raise error when there are two files" do
        let(:image_path) { ["1", "2"] }

        it { expect { subject }.to raise_error(API::V1::Exceptions::InvalidResourcesError) }
      end

      context "should raise error when there is no file" do
        let(:image_path) { [] }

        it { expect { subject }.to raise_error(API::V1::Exceptions::InvalidResourcesError) }
      end
    end
  end
end
