class Form::MasterAdmin
  include ActiveModel::Model

  attr_accessor :id, :display_name, :username, :email, :password, :password_confirmation, :note, :role, :current_user

  validates :username, presence: true
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP, message: "format is invalid" }
  validates :password, presence: true, confirmation: true, length: { minimum: 8 }, if: :password_required?
  validate :validate_role_assignment
  validate :validate_username_uniqueness
  validate :validate_email_uniqueness

  def initialize(attributes = {})
    super(attributes.to_h.symbolize_keys)
  end

  def save
    return false unless valid?

    ActiveRecord::Base.transaction do
      account = create_or_update_account!
      create_or_update_user!(account)
    end
    true
  rescue ActiveModel::ValidationError => e
    errors.merge!(e.model.errors)
    false
  rescue ActiveRecord::RecordInvalid => e
    errors.add(:base, e.record.errors.full_messages.join(", "))
    false
  end

  def update(params)
    self.attributes = params
    save
  end

  private

  def create_or_update_account!
    account = nil
    if id.present?
      user = User.find_by(id: id)
      account = user&.account
    end
    account ||= Account.where(username: username).first_or_initialize

    account.assign_attributes(
      username: username,
      display_name: display_name,
      note: note
    )

    unless account.valid?
      raise ActiveModel::ValidationError.new(account)
    end

    account.save!
    account
  end

  def create_or_update_user!(account)
    role_record = if role.to_s.match?(/\A\d+\z/)
                    UserRole.find_by(id: role)
                  else
                    UserRole.find_by(name: role)
                  end
    role_record ||= UserRole.find_by!(name: 'MasterAdmin')

    user = nil
    if id.present?
      user = User.find_by(id: id)
    end
    user ||= User.where(email: email).first_or_initialize

    user.assign_attributes(
      email: email,
      confirmed_at: Time.current,
      role: role_record,
      account: account,
      agreement: true,
      approved: true
    )

    if password.present?
      user.assign_attributes(
        password: password,
        password_confirmation: password_confirmation
      )
    end

    unless user.valid?
      raise ActiveModel::ValidationError.new(user)
    end

    user.save!
  end

  private

  def validate_role_assignment
    return unless current_user.present?
    return if current_user.master_admin?

    assigned_role = if role.to_s.match?(/\A\d+\z/)
                      UserRole.find_by(id: role)
                    else
                      UserRole.find_by(name: role)
                    end

    if assigned_role && !current_user.role.overrides?(assigned_role)
      errors.add(:role, "cannot be equal to or higher than your own role")
    end
  end

  def validate_username_uniqueness
    return if username.blank?

    if id.nil?
      if Account.exists?(username: username)
        errors.add(:username, "has already been taken")
      end
    else
      user = User.find_by(id: id)
      existing_account = Account.find_by(username: username)
      if existing_account && existing_account.id != user&.account_id
        errors.add(:username, "has already been taken")
      end
    end
  end

  def validate_email_uniqueness
    return if email.blank?

    if id.nil?
      if User.exists?(email: email)
        errors.add(:email, "has already been taken")
      end
    else
      existing_user = User.find_by(email: email)
      if existing_user && existing_user.id.to_s != id.to_s
        errors.add(:email, "has already been taken")
      end
    end
  end

  def password_required?
    id.nil? || password.present?
  end
end
