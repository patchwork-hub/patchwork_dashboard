require 'spreadsheet'

class Account < ApplicationRecord
  IMAGE_MIME_TYPES = ['image/jpeg', 'image/png', 'image/gif', 'image/webp'].freeze
  NAME_LENGTH_LIMIT = 30

  has_one :user, inverse_of: :account

  before_create :generate_keys

  has_attached_file :avatar

  has_attached_file :header

  validates_attachment_content_type :avatar, content_type: IMAGE_MIME_TYPES
  validates_attachment_content_type :header, content_type: IMAGE_MIME_TYPES

  validates :display_name, presence: true,
    length: { maximum: NAME_LENGTH_LIMIT, too_long: "cannot be longer than %{count} characters" }

  validates :username, presence: true,
    format: { with: /\A[a-z0-9_]+\z/i, message: "only allows letters, numbers, and underscores" },
    length: { maximum: NAME_LENGTH_LIMIT, too_long: "cannot be longer than %{count} characters" }

  def self.ransackable_attributes(auth_object = nil)
    ["dob", "domain", "uri", "url", "username"]
  end

  def followed?(target_account_id)
    Follow.exists?(account_id: id, target_account_id: target_account_id)
  end

  def self.filter_unfollowed_users(account_id)
    Account.left_joins(:follows)
           .where.not(follows: { account_id: account_id })
           .distinct
  end

  def avatar_url
    if avatar_remote_url.present?
      avatar_remote_url
    elsif avatar_file_name.present?
      "https://#{ENV['S3_BUCKET']}/accounts/avatars/#{id}/original/#{avatar_file_name}"
    else
      ActionController::Base.helpers.asset_path('patchwork-logo.svg')
    end
  end

  def generate_keys
    return unless local? && private_key.blank? && public_key.blank?

    keypair = OpenSSL::PKey::RSA.new(2048)
    self.private_key = keypair.to_pem
    self.public_key  = keypair.public_key.to_pem
  end

  def local?
    domain.nil?
  end

end
