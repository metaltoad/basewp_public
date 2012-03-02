 # The project repo name. (one word: no spaces, dashes, or underscores)
set :application, "basewp"

# Legacy from porting from drupal, best to just leave this as "default"
set :domains, ["default"]

# Set the repository type and location to deploy from.
set :scm, :git
set :repository,  "git@github.com:your_github_account/#{application}.git"
# set :scm, :subversion
# set :repository,  "https://svn.example.com/svn/#{application}/trunk/"
# set(:scm_password) { Capistrano::CLI.password_prompt("SCM Password: ") }

# Set the database passwords that we'll use for maintenance. Probably only used
# during setup.
set(:db_root_pass) { Capistrano::CLI.password_prompt("Production Root MySQL password: ") }
set(:db_pass) { random_password }

# The subdirectory within the repo containing the DocumentRoot.
set :app_root, "wordpress"

# Use a remote cache to speed things up
set :deploy_via, :remote_cache
ssh_options[:user] = 'deploy'

# Multistage support - see config/deploy/[STAGE].rb for specific configs
set :default_stage, "dev"
set :stages, %w(dev staging prod)

# Generally don't need sudo for this deploy setup
set :use_sudo, false

# This allows the sudo command to work if you do need it
default_run_options[:pty] = true

# Override these in your stage files if your web server group is something other than apache
set :httpd_group, 'apache'


#set this to where you have installed your wp site locally (http://[local_domain]/wp-admin/ should exist. )
set :local_domain, 'basewp.chrisbot'