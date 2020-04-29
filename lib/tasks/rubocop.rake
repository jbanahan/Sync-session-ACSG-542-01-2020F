namespace :rubocop do
  desc 'Runs a full rubocop scan.'
  task scan: :environment do
    sh 'rubocop'
  end
end
