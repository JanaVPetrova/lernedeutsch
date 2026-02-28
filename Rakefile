require 'dotenv/load'
require 'active_record'
require 'yaml'
require 'erb'

def db_config
  env = ENV['RACK_ENV'] || 'development'
  config = YAML.safe_load(ERB.new(File.read('config/database.yml')).result, aliases: true)
  config[env]
end

def establish_connection(config = db_config)
  ActiveRecord::Base.establish_connection(config)
end

namespace :db do
  task :environment do
    establish_connection
  end

  task :create do
    config = db_config
    db_name = config['database']
    establish_connection(config.merge('database' => 'postgres'))
    ActiveRecord::Base.connection.create_database(db_name)
    puts "Database '#{db_name}' created."
  rescue ActiveRecord::DatabaseAlreadyExists
    puts "Database '#{db_name}' already exists."
  end

  task migrate: :environment do
    ActiveRecord::Migration.verbose = true
    ActiveRecord::MigrationContext.new('db/migrations').migrate
  end

  task rollback: :environment do
    ActiveRecord::Migration.verbose = true
    ActiveRecord::MigrationContext.new('db/migrations').rollback
  end

  task drop: :environment do
    config = db_config
    db_name = config['database']
    establish_connection(config.merge('database' => 'postgres'))
    ActiveRecord::Base.connection.drop_database(db_name)
    puts "Database '#{db_name}' dropped."
  end

  task reset: %i[drop create migrate]
end
