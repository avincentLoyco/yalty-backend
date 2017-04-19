class RemoveOrphanGenericFiles < ActiveJob::Base
  queue_as :generic_files

  def perform
    ids_of_orphan_files =
      GenericFile.orphans.where('created_at < ?', 1.day.ago.beginning_of_day).ids
    GenericFile.where(id: ids_of_orphan_files).delete_all
    ids_of_orphan_files.each do |id|
      path = Rails.application.config.file_upload_root_path.join(id)
      next unless Dir.exist?(path)
      FileUtils.remove_entry_secure(path)
    end
  end
end
