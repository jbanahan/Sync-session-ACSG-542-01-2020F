namespace :rubocop do
  desc 'Runs a full rubocop scan.'
  task scan: :environment do
    sh 'rubocop --config .rubocop/rubocop.yml --parallel'
  end

  desc 'Scans only files that diverge from master branch.'
  task branch: :environment do
    sh 'git diff --diff-filter=d --name-only master | xargs rubocop --config .rubocop/rubocop.yml --parallel'
  end

  desc 'Scans only files that diverge from master branch and safely auto corrects'
  task branch_ac: :environment do
    sh 'git diff --diff-filter=d --name-only master | xargs rubocop --config .rubocop/rubocop.yml --safe-auto-correct'
  end
end

# This allows you to do `rake rubocop` to run a scan (instead of `rake rubocop:scan`)
task rubocop: ["rubocop:scan"]