class FileStorageUploadDownload
  class << self
    KEYS_WHITELIST = %w(token attachment version action_type).freeze

    def call(env)
      request = Rack::Request.new(env)
      params = request.params.select { |key, _| KEYS_WHITELIST.include?(key) }
      token_data = manage_token(params['token'])

      return error_response if token_data.empty? || params.empty?

      if request.post? then upload_file(token_data, params)
      elsif request.get?  then download_file(token_data, params, get_file_id(env['PATH_INFO']))
      else [405, { 'Content-Type' => 'text/plain' }, ['Method Not Allowed']]
      end
    end

    private

    def upload_file(token_data, params)
      return error_response if invalid_params_for_upload?(token_data, params)
      IO.copy_stream(
        params['attachment'][:tempfile],
        path_for_upload(token_data['file_id'], params['attachment'][:filename])
      )
      response = { message: 'File uploaded', file_id: token_data['file_id'], type: 'file' }
      [200, { 'Content-Type' => 'application/json' }, [response.to_json]]
    end

    def download_file(token_data, params, file_id)
      return error_response if invalid_params_for_download?(token_data, params, file_id)
      path = path_for_download(file_id, params['version'])
      file = File.open(path)
      return error_response if sha_checksum_incorrect?(file, token_data)
      [200, { 'Content-Type' => token_data['file_type'] }, file]
    end

    def invalid_params_for_upload?(token_data, params)
      token_data['action_type'] != 'upload' ||
        params['action_type'] != token_data['action_type'] ||
        !params['attachment'].is_a?(Hash) ||
        params['attachment'].is_a?(Hash) && !params['attachment'][:tempfile].is_a?(Tempfile)
    end

    def invalid_params_for_download?(token_data, params, file_id)
      token_data['action_type'] != 'download' ||
        token_data['file_id'] != file_id ||
        params['action_type'] != token_data['action_type']
    end

    def get_file_id(path)
      %r{(.+|^)/(.+)$}.match(path)[2]
    end

    def manage_token(token)
      redis = Redis.current

      token_data, counter = redis.multi do
        redis.hgetall(token)
        redis.hincrby(token, 'counter', -1)
      end

      if token_data.empty? || token_data['duration'].eql?('shortterm') && counter && counter < 0
        redis.del(token)
        token_data = {}
      end

      token_data
    end

    def path_for_upload(file_id, filename)
      file_storage_path = File.join(ENV['FILE_STORAGE_UPLOAD_PATH'], file_id, 'original')
      FileUtils.mkdir_p(file_storage_path)
      File.join(Dir.pwd, file_storage_path, filename)
    end

    def path_for_download(file_id, version)
      version_directory = version ? version : 'original'
      file_storage_path =
        File.join(ENV['FILE_STORAGE_UPLOAD_PATH'], file_id, version_directory, '*')
      files_in_directory = Dir.glob(file_storage_path)
      return error_response if files_in_directory.size != 1
      files_in_directory.first
    end

    def sha_checksum_incorrect?(file, token_data)
      Digest::SHA256.file(file).hexdigest != token_data['file_sha']
    end

    def error_response
      [403, { 'Content-Type' => 'text/plain' }, ['Something went wrong']]
    end
  end
end
