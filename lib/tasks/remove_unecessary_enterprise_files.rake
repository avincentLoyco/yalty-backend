task remove_unecessary_enterprise_files: :environment do
  file_path = ENV['FILE_STORAGE_UPLOAD_PATH']
  return unless File.directory?(file_path)

  deleted_files = []

  puts 'Enterprise files:'
  company_events_files.each do |file_id|
    puts file_id

    original_path = Pathname.new(file_path).join(file_id, 'original')
    next unless File.directory?(original_path) && original_path.children.size > 1

    original_path.each_child do |file|
      next unless file.basename.to_s.include?(' ')

      deleted_files << file_id
      file.delete
    end
  end

  puts
  puts 'Deleted duplicates:'
  deleted_files.each do |file_id|
    puts file_id
  end
end

def company_events_files
  CompanyEvent.all.map { |event| event.files.ids }.flatten!
end
