class GenericFile < ActiveRecord::Base
  IMAGES_TYPES   = %w(image/jpg image/jpeg image/png).freeze
  DOCUMENT_TYPES = %w(
    application/pdf application/msword
    application/vnd.openxmlformats-officedocument.wordprocessingml.document
  ).freeze
  EXPORT_TYPES = %w(application/zip).freeze
  CONTENT_TYPES = (IMAGES_TYPES + DOCUMENT_TYPES + EXPORT_TYPES).freeze

  belongs_to :fileable, polymorphic: true

  serialize :sha_sums, ShaAttribute

  scope(:orphans, lambda do
    where.not(id:
      Employee::AttributeVersion
      .where("data -> 'attribute_type' = 'File'")
      .select("(data -> 'id')::uuid"))
    .where(fileable_id: nil)
  end)

  has_attached_file :file, styles: { thumbnail: ['296x235^'] }

  before_post_process :process_only_images
  after_save :rename_file, :generate_sha, if: -> { file.present? }
  validates :file,
    attachment_content_type: { content_type: CONTENT_TYPES },
    attachment_size: { less_than: 20.megabytes }

  def find_file_path(version = 'original')
    Dir.glob(Rails.application.config.file_upload_root_path.join(id, version, '*'))
  end

  def user_friendly_name
    send("#{fileable_type.underscore}_friendly_name") + ".#{extension}"
  end

  private

  def account_friendly_name
    date = file_updated_at.strftime('%Y%m%d')
    "archive-#{fileable.subdomain}-#{date}"
  end

  def invoice_friendly_name
    date = fileable.date.strftime('%Y%m%d')
    "invoice-#{date}"
  end

  def employee_file_friendly_name
    Employee::AttributeVersion
      .includes(:attribute_definition)
      .where("data -> 'attribute_type' = 'File' AND data -> 'id' = '#{id}'")
      .first
      .attribute_definition
      .name
  end

  def rename_file
    new_name = "file_#{id}.#{extension}"
    return if file_file_name.eql?(new_name)
    file.instance_write(:file_name, new_name)
  end

  def extension
    MIME::Types[file_content_type].first.extensions.first
  end

  def generate_sha
    update_column(
      :sha_sums,
      file.styles.keys.map(&:to_s).push('original').each_with_object({}) do |version, sha|
        file_path = find_file_path(version)
        next if file_path.empty?
        sha[:"#{version}_sha"] = Digest::SHA256.file(file_path.first).hexdigest
      end
    )
  end

  def process_only_images
    IMAGES_TYPES.include?(file_content_type)
  end
end
