class FindValueForAttribute
  include API::V1::Exceptions

  attr_reader :attribute, :attribute_type, :employee_file, :file_path

  def initialize(attribute, version)
    @attribute = attribute
    @attribute_type = version.attribute_definition.try(:attribute_type)
  end

  def call
    return attribute[:value] unless attribute_type && attribute_type.eql?('File')
    @employee_file = EmployeeFile.find(attribute[:value])
    @file_path = employee_file.find_file_path
    verify_if_one_file_in_directory!
    employee_file.update!(file: File.open(file_path.first, 'r'))
    form_employee_attribute_version
  end

  private

  def verify_if_one_file_in_directory!
    return unless file_path.size != 1
    raise InvalidResourcesError.new(employee_file, 'Not authorized!')
  end

  def form_employee_attribute_version
    {
      id: attribute[:value],
      size: employee_file.file_file_size.to_f,
      file_type: employee_file.file_content_type,
      file_sha: Digest::SHA256.file(file_path.first).hexdigest
    }
  end
end
