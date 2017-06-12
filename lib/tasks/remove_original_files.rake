task remove_original_files: :environment do
  file_path = ENV['FILE_STORAGE_UPLOAD_PATH']
  return unless File.directory?(file_path)

  Pathname(file_path).each_child do |file_id_folder|
    original_path = file_id_folder.join('original')
    next unless original_path.exist?
    file_name = 'file_' + file_id_folder.basename.to_s
    existing_files = Pathname(original_path).children
    next if existing_files.size <= 1
    existing_files.each do |filename|
      next if filename.basename.to_s.include?(file_name)
      filename.delete
    end
  end
end
