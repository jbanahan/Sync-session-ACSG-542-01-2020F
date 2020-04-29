namespace :rubocop do
  desc 'Runs a full rubocop scan.'
  task scan: :environment do
    sh 'rubocop'
  end

  desc 'Scans only files that diverge from master branch.'
  task branch: :environment do
    sh 'git diff --name-only master | xargs rubocop'
  end
end
