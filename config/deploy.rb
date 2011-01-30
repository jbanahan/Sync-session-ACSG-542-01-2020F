set :application, "demo.chain.io"
set :user, "ubuntu"
set :repository, "."
#set :repository,  "git@github.com:bglick/OpenChain.git"

set :scm, :git # Or: `accurev`, `bzr`, `cvs`, `darcs`, `git`, `mercurial`, `perforce`, `subversion` or `none`
set :scm_username, user
default_run_options[:pty] = true # Must be set for the password prompt from git to work
ssh_options[:forward_agent] = true
ssh_options[:keys] = [File.join(ENV["HOME"], ".ssh", "id_rsa")]
set :branch, "master"
set :scm_verbose, true
set :deploy_via, :copy
# set :deploy_via, :remote_cache

set :deploy_to, "/var/www/apps/#{application}"

# Sloppy use of AWS endpoints
set :ec2_endpoint, "ec2-50-16-234-181.compute-1.amazonaws.com"
set :rds_endpoint, "aspectinstance.cznbgfbl22bb.us-east-1.rds.amazonaws.com"

role :web, ec2_endpoint                          # Your HTTP server, Apache/etc
role :app, ec2_endpoint                          # This may be the same as your `Web` server
role :db,  rds_endpoint, :primary => true # This is where Rails migrations will run
#role :db,  rds_endpoint

# If you are using Passenger mod_rails uncomment this:
# if you're still using the script/reapear helper you will need
# these http://github.com/rails/irs_process_scripts

# namespace :deploy do
#   task :start do ; end
#   task :stop do ; end
#   task :restart, :roles => :app, :except => { :no_release => true } do
#     run "#{try_sudo} touch #{File.join(current_path,'tmp','restart.txt')}"
#   end
# end