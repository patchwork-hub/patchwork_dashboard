# == Schema Information
#
# Table name: relays
#
#  id                 :bigint           not null, primary key
#  inbox_url          :string           default(""), not null
#  state              :integer          default("idle"), not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  follow_activity_id :string
#
class Relay < ApplicationRecord
  enum :state, { idle: 0, pending: 1, accepted: 2, rejected: 3 }
end
