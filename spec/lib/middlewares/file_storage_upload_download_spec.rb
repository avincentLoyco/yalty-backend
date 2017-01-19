require File.expand_path('lib/middlewares/file_storage_upload_download.rb')
require 'spec_helper'
require 'rack/test'
require 'fakeredis/rspec'

RSpec.describe FileStorageUploadDownload do
  include Rack::Test::Methods

  let(:app) { described_class }
  let(:token) { 'some_totally_random_token' }
  let(:counter) { 1 }
  let(:file_sha) { nil }
  let(:file_type) { 'image/jpg' }
  let(:source_path) { File.join(Dir.pwd, '/spec/fixtures/files/test.jpg') }
  let(:file_id) { 'some_random_id' }
  let(:duration) { 'shortterm' }

  subject(:set_token_in_redis) do
    Redis.current.hmset(token, 'file_id', file_id, 'counter', counter, 'file_sha', file_sha,
      'action_type', action_type, 'file_type', file_type, 'duration', duration)
  end

  subject(:get_token) { Redis.current.hgetall(token) }

  describe 'upload' do
    subject(:post_request) { post('/files', params) }

    let(:action_type) { 'upload' }
    let(:file) { Rack::Test::UploadedFile.new(source_path, file_type) }
    let(:params) {{ token: token, attachment: file, action_type: action_type }}
    let(:response) {{ 'message' => 'File uploaded', 'file_id' => file_id, 'type' => 'file' }}
    let(:file_saved) { File.exist?(File.join('tmp/files', file_id, 'original/test.jpg')) }

    context 'valid response' do
      before do
        set_token_in_redis
        post_request
      end

      it { expect(last_response.status).to eq(200) }
      it { expect(JSON.parse(last_response.body)).to match(response) }
      it { expect(get_token['counter']).to eq('0') }
      it { expect(file_saved).to eq(true) }
    end

    context 'invalid params' do
      context 'no params' do
        let(:params) {}

        before do
          set_token_in_redis
          post_request
        end

        it { expect(last_response.status).to eq(403) }
        it { expect(file_saved).to eq(false) }
      end

      context 'token' do
        let(:params) {{ token: '098890', attachment: file, action_type: action_type }}

        before do
          set_token_in_redis
          post_request
        end

        it { expect(last_response.status).to eq(403) }
        it { expect(file_saved).to eq(false) }
      end

      context 'attachment' do
        let(:params) {{ token: token, attachment: 'file', action_type: action_type }}

        before do
          set_token_in_redis
          post_request
        end

        it { expect(last_response.status).to eq(403) }
        it { expect(file_saved).to eq(false) }
      end

      context 'action_type' do
        let(:params) {{ token: token, attachment: file, action_type: 'download' }}

        before do
          set_token_in_redis
          post_request
        end

        it { expect(last_response.status).to eq(403) }
        it { expect(file_saved).to eq(false) }
      end
    end

    context 'token' do
      context 'does not exist' do
        before { post_request }

        it { expect(last_response.status).to eq(403) }
        it { expect(get_token).to eq({}) }
        it { expect(file_saved).to eq(false) }
      end

      context 'contains wrong data' do
        context 'action_type' do
          let(:action_type) { 'download' }
          let(:params) {{ token: token, attachment: file, action_type: 'upload' }}

          before do
            set_token_in_redis
            post_request
          end

          it { expect(last_response.status).to eq(403) }
          it { expect(get_token['counter']).to eq('0') }
          it { expect(file_saved).to eq(false) }
        end
      end
    end

    context 'counter' do
      context 'is bigger than 1' do
        let(:counter) { 5 }

        before do
          set_token_in_redis
          post_request
        end

        it { expect(last_response.status).to eq(200) }
        it { expect(get_token['counter']).to eq('4') }
        it { expect(file_saved).to eq(true) }
      end

      context 'is 0' do
        let(:counter) { 0 }

        before do
          set_token_in_redis
          post_request
        end

        it { expect(last_response.status).to eq(403) }
        it { expect(get_token).to eq({}) }
        it { expect(file_saved).to eq(false) }
      end
    end
  end

  describe 'download' do
    subject(:get_request) { get("/files/#{file_id}", params) }

    let(:dir_path) { "#{Dir.pwd}/#{ENV['FILE_STORAGE_UPLOAD_PATH']}/#{file_id}/original" }
    let(:destination_path) { "#{dir_path}/test.jpg" }
    let(:employee_file) { File.open(destination_path) }
    let(:action_type) { 'download' }
    let(:file_sha) { Digest::SHA256.file(employee_file).hexdigest }
    let(:params) {{ token: token, action_type: action_type }}

    subject(:create_file) do
      FileUtils.mkdir_p(dir_path)
      FileUtils.cp(source_path, destination_path)
    end

    context 'valid response' do
      before do
        create_file
        set_token_in_redis
        get_request
      end

      it { expect(last_response.status).to eq(200) }
      it { expect(last_response.body).to_not be_empty }
      it { expect(last_response.original_headers).to eq('Content-Type' => 'image/jpg') }
      it { expect(last_response.length).to eq(employee_file.size) }
      it { expect(get_token['counter']).to eq('0') }
    end

    context 'longterm token does not consider counter' do
      let(:duration) { 'longterm' }
      let(:counter) { 0 }

      before do
        create_file
        set_token_in_redis
        get_request
      end

      it { expect(last_response.status).to eq(200) }
      it { expect(get_token['counter']).to eq('-1') }
    end

    context 'invalid params' do
      context 'file_id' do
        context 'different id' do
          before do
            create_file
            set_token_in_redis
            get("/files/different_id", params)
          end

          it { expect(last_response.status).to eq(403) }
          it { expect(last_response.body).to eq('Something went wrong') }
          it { expect(get_token['counter']).to eq('0') }
        end

        context 'blank file_id' do
          before do
            create_file
            set_token_in_redis
            get("/files", params)
          end

          it { expect(last_response.status).to eq(403) }
          it { expect(last_response.body).to eq('Something went wrong') }
          it { expect(get_token['counter']).to eq('0') }
        end
      end

      context 'token' do
        let(:params) {{ token: '098890', action_type: action_type }}

        before do
          create_file
          set_token_in_redis
          get_request
        end

        it { expect(last_response.status).to eq(403) }
        it { expect(last_response.body).to eq('Something went wrong') }
      end

      context 'action_type' do
        let(:params) {{ token: token, action_type: 'upload' }}

        before do
          create_file
          set_token_in_redis
          get_request
        end

        it { expect(last_response.status).to eq(403) }
        it { expect(last_response.body).to eq('Something went wrong') }
        it { expect(get_token['counter']).to eq('0') }
      end
    end

    context 'token' do
      context 'does not exist' do
        before do
          create_file
          get_request
        end

        it { expect(last_response.status).to eq(403) }
        it { expect(last_response.body).to eq('Something went wrong') }
      end

      context 'contains wrong data' do
        context 'action_type' do
          let(:action_type) { 'upload' }
          let(:params) {{ token: token, action_type: 'download' }}

          before do
            create_file
            set_token_in_redis
            get_request
          end

          it { expect(last_response.status).to eq(403) }
          it { expect(last_response.body).to eq('Something went wrong') }
          it { expect(get_token['counter']).to eq('0') }
        end

        context 'file_id' do
          before do
            create_file
            Redis.current.hmset(token, 'file_id', '90889', 'counter', counter, 'file_sha', file_sha,
              'action_type', action_type, 'file_type', file_type)
            get_request
          end

          it { expect(last_response.status).to eq(403) }
          it { expect(last_response.body).to eq('Something went wrong') }
          it { expect(get_token['counter']).to eq('0') }
        end

        context 'file_sha' do
          let(:file_sha) { '12334' }

          before do
            create_file
            set_token_in_redis
            get_request
          end

          it { expect(last_response.status).to eq(403) }
          it { expect(last_response.body).to eq('Something went wrong') }
          it { expect(get_token['counter']).to eq('0') }
        end
      end
    end
  end
end
