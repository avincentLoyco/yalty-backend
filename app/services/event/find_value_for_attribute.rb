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
    employee_file = assign_file_to_employee_file!(attribute[:value])
    form_employee_attribute_version(employee_file)
  end

  private

  def assign_file_to_employee_file!(file_id)
    employee_file = EmployeeFile.find(file_id)
    file_path = employee_file.find_file_path
    verify_if_one_file_in_directory!(file_path, employee_file)
    file_name = "file_#{file_id}#{File.extname(file_path.first).downcase}"
    employee_file.update!(file: File.open(file_path.first, 'r'), file_file_name: file_name)
    employee_file
  end

  def verify_if_one_file_in_directory!(file_path, employee_file)
    return unless (employee_file.id != version.data&.id && file_path.size != 1) || file_path.blank?
    raise InvalidResourcesError.new(employee_file, ['Not authorized!'])
  end

  def form_employee_attribute_version(employee_file)
    {
      id: attribute[:value],
      size: employee_file.file_file_size.to_f,
      file_type: employee_file.file_content_type
    }.merge(shasum(employee_file))
  end

  def shasum(employee_file)
    employee_file.file.styles.keys.map(&:to_s).push('original').each_with_object({}) do |v, sha|
      next if employee_file.find_file_path(v).empty?
      sha[:"#{v}_sha"] = Digest::SHA256.file(employee_file.find_file_path(v).first).hexdigest
    end
  end
end
