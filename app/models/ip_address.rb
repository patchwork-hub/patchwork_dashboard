# == Schema Information
#
# Table name: ip_addresses
#
#  id          :bigint           not null, primary key
#  ip          :string           not null
#  private_ip  :string
#  reserved_at :datetime
#  use_count   :integer          default(0), not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
# Indexes
#
#  index_ip_addresses_on_ip  (ip) UNIQUE
#
class IpAddress < ApplicationRecord
  LIMIT_USAGE = 15
  RESERVATION_WINDOW = 1.hour
  has_many :communities

  validates :ip, presence: true, uniqueness: true, format: { with: Resolv::IPv4::Regex, message: "must be a valid IPv4 address" }

  def self.valid_ip
    ip = where("use_count < ?", LIMIT_USAGE)
         .where("reserved_at IS NULL OR reserved_at < ?", RESERVATION_WINDOW.ago)
         .order(id: :asc, use_count: :desc)
         .limit(1)
         .first

    if ip&.use_count == LIMIT_USAGE - 2
      transaction do
        ip = where(id: ip.id).lock("FOR UPDATE").first
        ip.update!(reserved_at: Time.current)
      end
    end

    ip
  end

  def increment_use_count!
    update!(use_count: use_count + 1, reserved_at: nil)
  end
end
