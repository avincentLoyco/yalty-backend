class RemoveOrphanEmployeeFiles < ActiveJob::Base
  queue_as :employee_files

  def perform
    ids_of_orphan_files =
      EmployeeFile.orphans.where('created_at < ?', 1.day.ago.beginning_of_day).ids
    EmployeeFile.where(id: ids_of_orphan_files).delete_all
    ids_of_orphan_files.each do |id|
      path = Rails.application.config.file_upload_root_path.join(id)
      next unless Dir.exist?(path)
      FileUtils.remove_entry_secure(path)
    end
  end
end
