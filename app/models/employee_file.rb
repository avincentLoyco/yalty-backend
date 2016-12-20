class EmployeeFile < ActiveRecord::Base
  CONTENT_TYPES = %w(image/jpg image/jpeg image/png application/pdf application/msword
                     application/vnd.openxmlformats-officedocument.wordprocessingml.document).freeze

  scope(:orphans, lambda do
    where.not(id:
      Employee::AttributeVersion
      .where("data -> 'attribute_type' = 'File'")
      .select("(data -> 'id')::uuid"))
  end)

  has_attached_file :file
  validates :file,
    attachment_content_type: { content_type: CONTENT_TYPES },
    attachment_size: { less_than: 20.megabytes }

  def find_file_path
    Dir.glob("files/#{id}/original/*")
  end
end
