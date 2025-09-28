# frozen_string_literal: true
username = ENV['MASTER_ADMIN_USERNAME']
email = ENV['MASTER_ADMIN_EMAIL']
password = ENV['MASTER_ADMIN_PASSWORD']

# Create or update admin account  
admin = Account.where(username: username).first_or_initialize(username: username)  
admin.save(validate: false)  

# Create or update admin user with MasterAdmin role  
user = User.where(email: email).first_or_initialize(  
  email: email,  
  password: password,  
  password_confirmation: password,  
  confirmed_at: Time.now.utc,  
  role: UserRole.find_by(name: 'MasterAdmin'),  
  account: admin,  
  agreement: true,  
  approved: true
)  
user.save! 