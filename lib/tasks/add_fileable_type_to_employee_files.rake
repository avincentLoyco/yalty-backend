desc 'Add fileable_type to EmployeeFiles'
task add_fileable_type_to_employee_files: :environment do
  GenericFile.where(id: Employee::AttributeVersion
    .where("data -> 'attribute_type' = 'File'")
    .select("(data -> 'id')::uuid")
  ).each do |employee_file|
    next if employee_file.fileable_type.eql?('EmployeeFile')
    employee_file.update!(fileable_type: 'EmployeeFile')
  end
end
