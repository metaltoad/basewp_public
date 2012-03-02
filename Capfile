# TODO: Cap db:push should support rollback or backup in some way
# TODO: Better handling of database creation - perhaps make the deploy user a database admin?

load 'deploy' if respond_to?(:namespace) # cap2 differentiator
Dir['vendor/plugins/*/recipes/*.rb'].each { |plugin| load(plugin) }
load 'config/deploy.rb'

require 'capistrano/ext/multistage'

namespace :deploy do
  desc "Prepares one or more servers for deployment."
  task :setup, :roles => :web, :except => { :no_release => true } do
    dirs = [deploy_to, releases_path, shared_path]
    domains.each do |domain|
      dirs += [shared_path + "/#{domain}/files"]
      dirs += [shared_path + "/#{domain}/files/avatars"]
      dirs += [shared_path + "/#{domain}/files/uploads"]
      dirs += [shared_path + "/#{domain}/files/w3tc"]
      dirs += [shared_path + "/#{domain}/files/cache"]
    end
    dirs += %w(system).map { |d| File.join(shared_path, d) }
    run "mkdir -m 0775 -p #{dirs.join(' ')}"
    # add setgid bit, so that files/ contents are always in the httpd group
    run "chmod 2775 #{shared_path}/*/files"
    run "chmod 2775 #{shared_path}/*/files/avatars"
    run "chmod 2775 #{shared_path}/*/files/uploads"
    run "chmod 2775 #{shared_path}/*/files/w3tc"
    run "chmod 2775 #{shared_path}/*/files/cache"
    run "chgrp #{httpd_group} #{shared_path}/*/files"
    run "chgrp #{httpd_group} #{shared_path}/*/files/*"
  end

  desc "Create local local_config.php in shared/config"
  task :create_settings_php, :roles => :web do
    domains.each do |domain|
        configuration = <<-EOF
<?php

  define('DB_NAME', '#{short_name(domain)}');

  /** MySQL database username */
  define('DB_USER', '#{tiny_name(domain)}');

  /** MySQL database password */
  define('DB_PASSWORD', '#{db_pass}');

  /** MySQL hostname */
  define('DB_HOST', 'localhost');

EOF

      put configuration, "#{deploy_to}/#{shared_dir}/#{domain}/local-config.php"
    end
  end

  desc "link file dirs and the local_settings.php to the shared copy"
  task :symlink_files, :roles => :web do
    domains.each do |domain|
      # link settings file
      run "ln -nfs #{deploy_to}/#{shared_dir}/#{domain}/local-config.php #{release_path}/#{app_root}/local-config.php"
      # Link Various files directories (uploads, w3tc, avatars, cache)
      run "ln -nfs #{deploy_to}/#{shared_dir}/#{domain}/files/uploads #{release_path}/#{app_root}/wp-content/uploads"
      run "ln -nfs #{deploy_to}/#{shared_dir}/#{domain}/files/w3tc #{release_path}/#{app_root}/wp-content/w3tc"
      run "ln -nfs #{deploy_to}/#{shared_dir}/#{domain}/files/avatars #{release_path}/#{app_root}/wp-content/avatars"
      run "ln -nfs #{deploy_to}/#{shared_dir}/#{domain}/files/cache #{release_path}/#{app_root}/wp-content/cache"
    end
  end

  # desc '[internal] Touches up the released code.'
  task :finalize_update, :except => { :no_release => true } do
    run "chmod -R g+w #{release_path}"
    run "chmod 644 #{release_path}/#{app_root}/wp-config.php"
  end


  # Each of the following tasks are Rails specific. They're removed.
  task :migrate do
  end

  task :migrations do
  end

  task :cold do
  end

  task :start do
  end

  task :stop do
  end

  task :restart, :roles => :web do
  end

  after "deploy:setup",
    "deploy:create_settings_php",
    "db:create"

  after "deploy:update_code",
    "deploy:symlink_files"

  after "deploy",
    "deploy:cleanup"
end

namespace :db do
  desc "Download a backup of the database(s) from the given stage."
  task :down, :roles => :db, :only => { :primary => true } do
    domains.each do |domain|
      filename = "#{domain}_#{stage}.sql"
      temp = "/tmp/#{release_name}_#{application}_#{filename}"
      run "touch #{temp} && chmod 600 #{temp}"
      run_locally "mkdir -p db"
      run "cd #{deploy_to}/current/webroot && #{wp} db export --file=#{temp} && cd -"
      download("#{temp}", "db/#{filename}", :via=> :scp)
      search = "#{application}-#{stage}.example.com"
      replace = local_domain
      puts "searching (#{search}) and replacing (#{replace}) domain information"
      run_locally "sed -e 's/#{search}/#{replace}/g' -i .bak db/#{filename}"
      run "rm #{temp}"
    end
  end

  desc "Download and apply a backup of the database(s) from the given stage."
  task :pull, :roles => :db, :only => { :primary => true } do
    domains.each do |domain|
      filename = "#{domain}_#{stage}.sql"
      system "cd #{app_root} ; #{wp} db import --file=#{filename}"
    end
  end

  desc "Upload database(s) to the given stage."
  task :push, :roles => :db, :only => { :primary => true } do
    domains.each do |domain|
      filename = "#{domain}_#{stage}.sql"
      temp = "/tmp/#{release_name}_#{application}_#{filename}"
      run "touch #{temp} && chmod 600 #{temp}"
      replace = "#{application}-#{stage}.example.com"
      search = local_domain
      puts "searching (#{search}) and replacing (#{replace}) domain information"
      run_locally "sed -e 's/#{search}/#{replace}/g' -i .bak db/#{filename}"
      upload("db/#{filename}", "#{temp}", :via=> :scp)
      run "cd #{deploy_to}/current/webroot/ && #{wp} db import --file=#{temp}"
      run "rm #{temp}"
    end
  end

  desc "Create database"
  task :create, :roles => :db, :only => { :primary => true } do
    # Create and gront privs to the new db user
    domains.each do |domain|
      create_sql = "CREATE DATABASE IF NOT EXISTS \\\`#{short_name(domain)}\\\` ;
                    GRANT ALL ON \\\`#{short_name(domain)}\\\`.* TO '#{tiny_name(domain)}'@'localhost' IDENTIFIED BY '#{db_pass}';
                    FLUSH PRIVILEGES;"
      run "mysql -u root -p#{db_root_pass} -e \"#{create_sql}\""
      puts "Using pass: #{db_pass}"
    end
  end

  before "db:pull", "db:down"
end

namespace :files do
  desc "Download a backup of the wp-content (minus themes + plugins) directory from the given stage."
  task :pull, :roles => :web do
    domains.each do |domain|
      if exists?(:gateway)
        run_locally("rsync --recursive --times --omit-dir-times --chmod=ugo=rwX --rsh='ssh #{ssh_options[:user]}@#{gateway} ssh  #{ssh_options[:user]}@#{find_servers(:roles => :web).first.host}' --compress --human-readable --progress --exclude 'webroot/plugins' --exclude 'webroot/themes' :#{deploy_to}/#{shared_dir}/#{domain}/files/ webroot/wp-content/")
      else
        run_locally("rsync --recursive --times --omit-dir-times --chmod=ugo=rwX --rsh=ssh --compress --human-readable --progress --exclude 'webroot/plugins' --exclude 'webroot/themes' #{ssh_options[:user]}@#{find_servers(:roles => :web).first.host}:#{deploy_to}/#{shared_dir}/#{domain}/files/ webroot/wp-content/")
      end
    end
  end

  desc "Push a backup of the wp-content (minus themes + plugins) directory from the given stage."
  task :push, :roles => :web do
    domains.each do |domain|
      if exists?(:gateway)
        run_locally("rsync --recursive --times --omit-dir-times --chmod=ugo=rwX --rsh='ssh #{ssh_options[:user]}@#{gateway} ssh  #{ssh_options[:user]}@#{find_servers(:roles => :web).first.host}' --compress --human-readable --progress --exclude 'webroot/plugins' --exclude 'webroot/themes' webroot/wp-content/ :#{deploy_to}/#{shared_dir}/#{domain}/files/")
      else
        run_locally("rsync --recursive --times --omit-dir-times --chmod=ugo=rwX --rsh=ssh --compress --human-readable --progress --exclude 'webroot/plugins' --exclude 'webroot/themes' webroot/wp-content/ #{ssh_options[:user]}@#{find_servers(:roles => :web).first.host}:#{deploy_to}/#{shared_dir}/#{domain}/files/")
      end
    end
  end
end

def short_name(domain=nil)
  return "#{application}_#{stage}_#{domain}".gsub('.', '_')[0..63] if domain && domain != 'default'
  return "#{application}_#{stage}".gsub('.', '_')[0..63]
end

def tiny_name(domain=nil)
  return "#{application[0..5]}_#{stage.to_s[0..2]}_#{domain[0..4]}".gsub('.', '_') if domain && domain != 'default'
  return "#{application[0..11]}_#{stage.to_s[0..2]}".gsub('.', '_')
end

def random_password(size = 16)
  chars = (('A'..'Z').to_a + ('a'..'z').to_a + ('0'..'9').to_a) - %w(i o 0 1 l 0)
  (1..size).collect{|a| chars[rand(chars.size)] }.join
end
