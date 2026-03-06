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

      begin
        if defined?(Paperclip) && Paperclip.respond_to?(:io_adapters)
          adapter = Paperclip.io_adapters.for(value)
          if adapter && adapter.respond_to?(:path) && File.exist?(adapter.path)
            file = File.open(adapter.path, "rb")
            @opened_uploads << file
            return file
          end
        end
      rescue Errno::ENOENT
        return nil
      end

      if value.respond_to?(:path)
        begin
          path = value.path(:original)
          path = value.path if path.nil?
          return nil unless path && File.exist?(path)

          file = File.open(path, "rb")
          @opened_uploads << file
          return file
        rescue Errno::ENOENT
          return nil
        end
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