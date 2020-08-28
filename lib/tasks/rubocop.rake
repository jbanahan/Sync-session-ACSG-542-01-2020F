namespace :rubocop do
  desc 'Runs a full rubocop scan.'
  task scan: :environment do
    sh 'rubocop --parallel'
  end

  desc 'Scans only files that diverge from master branch.'
  task branch: :environment do
    sh 'git diff --diff-filter=d --name-only master | xargs rubocop --parallel'
  end

  desc 'Scans only files that diverge from master branch and safely auto corrects'
  task branch_ac: :environment do
    sh 'git diff --diff-filter=d --name-only master | xargs rubocop --safe-auto-correct'
  end
end
