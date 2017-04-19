class GenericFile < ActiveRecord::Base
  belongs_to :fileable, polymorphic: true

  IMAGES_TYPES   = %w(image/jpg image/jpeg image/png).freeze
  DOCUMENT_TYPES = %w(
    application/pdf application/msword
    application/vnd.openxmlformats-officedocument.wordprocessingml.document
  ).freeze
  CONTENT_TYPES = (IMAGES_TYPES + DOCUMENT_TYPES).freeze

  scope(:orphans, lambda do
    where.not(id:
      Employee::AttributeVersion
      .where("data -> 'attribute_type' = 'File'")
      .select("(data -> 'id')::uuid"))
    .where(fileable_id: nil)
  end)

  has_attached_file :file, styles: { thumbnail: ['296x235^'] }

  before_post_process :process_only_images
  after_save :rename_file, if: -> { file.present? }
  validates :file,
    attachment_content_type: { content_type: CONTENT_TYPES },
    attachment_size: { less_than: 20.megabytes }

  def find_file_path(version = 'original')
    Dir.glob(Rails.application.config.file_upload_root_path.join(id, version, '*'))
  end

  private

  def rename_file
    new_name = "file_#{id}#{File.extname(file.path).downcase}"
    return if file_file_name.eql?(new_name)
    file.instance_write(:file_name, new_name)
  end

  def process_only_images
    IMAGES_TYPES.include?(file_content_type)
  end
end
