class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  connects_to database: { writing: :primary, reading: :replica } if DatabaseHelper.replica_enabled?
end
