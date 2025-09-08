# == Schema Information
#
# Table name: patchwork_app_version_histories
#
#  id             :bigint           not null, primary key
#  deprecated     :boolean          default(FALSE)
#  os_type        :string
#  released_date  :datetime
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  app_version_id :bigint           not null
#
# Indexes
#
#  index_patchwork_app_version_histories_on_app_version_id  (app_version_id)
#
# Foreign Keys
#
#  fk_rails_...  (app_version_id => patchwork_app_versions.id)
#
class AppVersionHistory < ApplicationRecord
  self.table_name = 'patchwork_app_version_histories'
  belongs_to :app_version, class_name: "AppVersion", optional: true

  validates :released_date, presence: true
end
