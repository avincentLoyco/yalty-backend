class FindValueForAttribute
  include API::V1::Exceptions

  attr_reader :attribute, :attribute_type, :version

  def initialize(attribute, version)
    @attribute = attribute
    @version = version
    @attribute_type = version.attribute_definition.try(:attribute_type)
  end

  def call
    return attribute[:value] unless attribute_type && attribute_type.eql?('File') &&
        attribute[:value].present?
    generic_file = assign_file_to_employee_file!(attribute[:value])
    form_employee_attribute_version(generic_file)
  end

  private

  def assign_file_to_employee_file!(file_id)
    generic_file = GenericFile.find(file_id)
    file_path = generic_file.find_file_path
    verify_if_one_file_in_directory!(file_path, generic_file)
    file_name = "file_#{file_id}#{File.extname(file_path.first).downcase}"
    generic_file.update!(
      file: File.open(file_path.first, 'r'),
      file_file_name: file_name,
      fileable_type: 'EmployeeFile'
    )
    remove_original(file_path)
    generic_file
  end

  def remove_original(file_path)
    FileUtils.rm_f(file_path)
  end

  def verify_if_one_file_in_directory!(file_path, generic_file)
    return unless (generic_file.id != version.data&.id && file_path.size != 1) || file_path.blank?
    raise InvalidResourcesError.new(generic_file, ['Not authorized!'])
  end

  def form_employee_attribute_version(generic_file)
    {
      id: attribute[:value],
      size: generic_file.file_file_size.to_f,
      file_type: generic_file.file_content_type
    }.merge(generic_file.sha_sums)
  end
end
