# app/services/update_account_credentials_service.rb
# frozen_string_literal: true

require "httparty"

class UpdateAccountCredentialsService < BaseService
  def call(token:, display_name: nil, note: nil, avatar: nil, header: nil, api_base_url: ENV["MASTODON_INSTANCE_URL"])
    url = "#{api_base_url}/api/v1/accounts/update_credentials"
    headers = { "Authorization" => "Bearer #{token}" }
    @opened_uploads = []

    avatar_file = normalize_upload(avatar)
    header_file = normalize_upload(header)

    body = {}
    body[:display_name] = display_name if display_name
    body[:note] = note if note
    body[:avatar] = avatar_file if avatar_file
    body[:header] = header_file if header_file

    HTTParty.patch(
      url,
      headers: headers,
      body: body,
      multipart: body.key?(:avatar) || body.key?(:header)
    )
  ensure
    @opened_uploads&.each do |upload|
      upload.close if upload.respond_to?(:close) && !upload.closed?
    rescue IOError, Errno::EBADF
      nil
    end

    @opened_temp_paths&.each do |path|
      File.delete(path) if File.exist?(path)
    rescue StandardError
      nil
    end
  end

  private

  def normalize_upload(value)
    return nil if value.nil?

    return value if value.is_a?(File) || value.is_a?(Tempfile)

    if defined?(ActionDispatch::Http::UploadedFile) && value.is_a?(ActionDispatch::Http::UploadedFile)
      return value.tempfile
    end

    if defined?(Paperclip::Attachment) && value.is_a?(Paperclip::Attachment)
      return nil unless value.present?
      return nil if value.respond_to?(:exists?) && !value.exists?

      queued_file = value.queued_for_write[:original] if value.respond_to?(:queued_for_write)
      return queued_file if queued_file

      original_name = value.original_filename if value.respond_to?(:original_filename)
      original_name ||= "image_#{SecureRandom.hex(4)}.jpg"

      begin
        if defined?(Paperclip) && Paperclip.respond_to?(:io_adapters)
          adapter = Paperclip.io_adapters.for(value)
          
          require 'fileutils'
          tmp_dir = Rails.root.join('tmp', 'patchwork_uploads', SecureRandom.hex(8))
          FileUtils.mkdir_p(tmp_dir)
          tmp_file_path = File.join(tmp_dir, original_name)
          
          File.open(tmp_file_path, 'wb') do |f|
            f.write(adapter.read)
          end
          
          file = File.open(tmp_file_path, 'rb')
          
          @opened_uploads << file
          @opened_temp_paths ||= []
          @opened_temp_paths << tmp_file_path
          
          return file
        end
      rescue => e
        Rails.logger.error("Error creating temp upload file: #{e.message}")
        return nil
      end

      return nil
    end

    if value.is_a?(String) && File.exist?(value)
      file = File.open(value, "rb")
      @opened_uploads << file
      return file
    end

    raise ArgumentError, "Unsupported upload type: #{value.class}"
  end
end