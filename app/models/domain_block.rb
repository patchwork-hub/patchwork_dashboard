# frozen_string_literal: true

# == Schema Information
#
# Table name: domain_blocks
#
#  id              :bigint           not null, primary key
#  domain          :string           default(""), not null
#  obfuscate       :boolean          default(FALSE), not null
#  private_comment :text
#  public_comment  :text
#  reject_media    :boolean          default(FALSE), not null
#  reject_reports  :boolean          default(FALSE), not null
#  severity        :integer          default("silence")
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
# Indexes
#
#  index_domain_blocks_on_domain  (domain) UNIQUE
#

class DomainBlock < ApplicationRecord
  enum :severity, { silence: 0, suspend: 1, noop: 2 }, validate: true
end
