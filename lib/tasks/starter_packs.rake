namespace :starter_packs do
  desc 'Import starter pack JSON (SOURCE, DATA_DIR, DRY_RUN, RESOLVE_MISSING, SKIP_UNRESOLVED, USER_ID)'
  task import: :environment do
    StarterPackImportService.new(
      data_dir: ENV.fetch('DATA_DIR', Rails.root.join('config', 'data').to_s),
      source: ENV['SOURCE'],
      dry_run: ActiveModel::Type::Boolean.new.cast(ENV.fetch('DRY_RUN', 'false')),
      resolve_missing: ActiveModel::Type::Boolean.new.cast(ENV.fetch('RESOLVE_MISSING', 'true')),
      skip_unresolved: ActiveModel::Type::Boolean.new.cast(ENV.fetch('SKIP_UNRESOLVED', 'false')),
      user: ENV['USER_ID'].present? ? User.find(ENV['USER_ID']) : nil
    ).call
  end
end