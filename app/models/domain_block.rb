# frozen_string_literal: true

# == Schema Information
#
# Table name: domain_blocks
#
#  id              :bigint(8)        not null, primary key
#  domain          :string           default(""), not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  severity        :integer          default("silence")
#  reject_media    :boolean          default(FALSE), not null
#  reject_reports  :boolean          default(FALSE), not null
#  private_comment :text
#  public_comment  :text
#  obfuscate       :boolean          default(FALSE), not null
#

class DomainBlock < ApplicationRecord
  enum :severity, { silence: 0, suspend: 1, noop: 2 }, validate: true
end
