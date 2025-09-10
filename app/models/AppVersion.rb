# == Schema Information
#
# Table name: patchwork_app_versions
#
#  id           :bigint           not null, primary key
#  app_name     :integer          default("patchwork"), not null
#  version_name :string
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#
# Indexes
#
#  index_patchwork_app_versions_on_version_name_and_app_name  (version_name,app_name) UNIQUE
#
class AppVersion < ApplicationRecord
  VALID_VERSION_REGEX = /\A(\*|(\d+(\.(\*|\d+)){0,2}))\z/

  self.table_name = 'patchwork_app_versions'
  has_many :app_version_histories, class_name: "AppVersionHistory", dependent: :destroy

  validates :version_name, presence: true, uniqueness: { scope: :app_name, case_sensitive: false}
  validate :version_name_format

  enum app_name: { patchwork: 0, newsmast: 1 }

  # Virtual attribute for form handling
  attr_accessor :released_date

  private
  def version_name_format
    return if version_name.blank?

    unless version_name.match?(VALID_VERSION_REGEX)
      errors.add(:version_name, "must be in the format 1, 1.23, 1.23.456, 1.*, 1.23.*, or * (numbers and dots only, * allowed)")
    end
  end

end
