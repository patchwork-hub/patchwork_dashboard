# == Schema Information
#
# Table name: accounts
#
#  id                            :bigint           not null, primary key
#  actor_type                    :string
#  also_known_as                 :string           is an Array
#  attribution_domains           :string           default([]), is an Array
#  avatar_content_type           :string
#  avatar_file_name              :string
#  avatar_file_size              :integer
#  avatar_remote_url             :string
#  avatar_storage_schema_version :integer
#  avatar_updated_at             :datetime
#  devices_url                   :string
#  discoverable                  :boolean
#  display_name                  :string           default(""), not null
#  domain                        :string
#  featured_collection_url       :string
#  fields                        :jsonb
#  followers_url                 :string           default(""), not null
#  header_content_type           :string
#  header_file_name              :string
#  header_file_size              :integer
#  header_remote_url             :string           default(""), not null
#  header_storage_schema_version :integer
#  header_updated_at             :datetime
#  hide_collections              :boolean
#  inbox_url                     :string           default(""), not null
#  indexable                     :boolean          default(FALSE), not null
#  last_webfingered_at           :datetime
#  locked                        :boolean          default(FALSE), not null
#  memorial                      :boolean          default(FALSE), not null
#  note                          :text             default(""), not null
#  outbox_url                    :string           default(""), not null
#  private_key                   :text
#  protocol                      :integer          default(0), not null
#  public_key                    :text             default(""), not null
#  requested_review_at           :datetime
#  reviewed_at                   :datetime
#  sensitized_at                 :datetime
#  shared_inbox_url              :string           default(""), not null
#  silenced_at                   :datetime
#  suspended_at                  :datetime
#  suspension_origin             :integer
#  trendable                     :boolean
#  uri                           :string           default(""), not null
#  url                           :string
#  username                      :string           default(""), not null
#  created_at                    :datetime         not null
#  updated_at                    :datetime         not null
#  moved_to_account_id           :bigint
#
# Indexes
#
#  index_accounts_on_domain_and_id              (domain,id)
#  index_accounts_on_moved_to_account_id        (moved_to_account_id) WHERE (moved_to_account_id IS NOT NULL)
#  index_accounts_on_uri                        (uri)
#  index_accounts_on_url                        (url) WHERE (url IS NOT NULL)
#  index_accounts_on_username_and_domain_lower  (lower((username)::text), COALESCE(lower((domain)::text), ''::text)) UNIQUE
#  search_index                                 ((((setweight(to_tsvector('simple'::regconfig, (display_name)::text), 'A'::"char") || setweight(to_tsvector('simple'::regconfig, (username)::text), 'B'::"char")) || setweight(to_tsvector('simple'::regconfig, (COALESCE(domain, ''::character varying))::text), 'C'::"char")))) USING gin
#
# Foreign Keys
#
#  fk_rails_...  (moved_to_account_id => accounts.id) ON DELETE => nullify
#
require 'spreadsheet'

class Account < ApplicationRecord
  IMAGE_MIME_TYPES = ['image/jpeg', 'image/png', 'image/gif', 'image/webp'].freeze
  NAME_LENGTH_LIMIT = 30

  has_one :user, inverse_of: :account

  before_create :generate_keys

  has_attached_file :avatar

  has_attached_file :header

  has_many :followers, class_name: 'Follow', foreign_key: :target_account_id
  has_many :follows, foreign_key: :account_id
  has_many :follow_requests, foreign_key: :account_id
  has_many :joined_communities, class_name: 'JoinedCommunity', foreign_key: :account_id, dependent: :destroy
  has_many :communities, through: :joined_communities
  has_one :wait_list, foreign_key: :account_id, class_name: 'WaitList', dependent: :destroy
  has_one :community_admin, foreign_key: :account_id, class_name: 'CommunityAdmin', dependent: :destroy
  has_many :settings, class_name: 'Setting', foreign_key: :account_id, dependent: :destroy

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
      id_path = id.to_s.scan(/.{3}/).join('/')
      "https://#{ENV['S3_ALIAS_HOST']}/accounts/avatars/#{id_path}/original/#{avatar_file_name}"
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

  def follower_count
    followers.size
  end

  def following_count
    follows.size
  end

  def following_ids(account_id = nil)
    account_id = self.id if account_id.nil?
    follow_ids = Follow.where(account_id: account_id).pluck(:target_account_id)
    follow_request_ids = FollowRequest.where(account_id: account_id).pluck(:target_account_id)
    (follow_ids + follow_request_ids).uniq
  end

  def self.update_all_discoverability(value = false)
    update_all(
      discoverable: !value,
      indexable: !value
    )
  end
end
