class RemoveOrphanEmployeeFiles < ActiveJob::Base
  queue_as :employee_files

  def perform
    ids_of_orphan_files =
      EmployeeFile.orphans.where('created_at < ?', 1.day.ago.beginning_of_day).ids
    EmployeeFile.where(id: ids_of_orphan_files).delete_all
    ids_of_orphan_files.each do |id|
      FileUtils.remove_entry_secure(Rails.root.join(ENV['FILE_STORAGE_UPLOAD_PATH'], id))
    end
  end
end
