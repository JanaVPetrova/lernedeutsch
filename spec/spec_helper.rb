require 'dotenv'
Dotenv.load('.env.test', '.env')

ENV['RACK_ENV'] = 'test'

require 'active_record'
require 'factory_bot'
require 'database_cleaner/active_record'

# Database setup
require 'yaml'
require 'erb'
config = YAML.safe_load(ERB.new(File.read(File.join(__dir__, '..', 'config', 'database.yml'))).result, aliases: true)
ActiveRecord::Base.establish_connection(config['test'])

# Load models and services
Dir[File.join(__dir__, '..', 'lib', 'models', '*.rb')].each { |f| require f }
Dir[File.join(__dir__, '..', 'lib', 'services', '*.rb')].each { |f| require f }

# FactoryBot
FactoryBot.definition_file_paths = [File.join(__dir__, 'support')]
FactoryBot.find_definitions

RSpec.configure do |config|
  config.include FactoryBot::Syntax::Methods

  config.before(:suite) do
    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.clean_with(:truncation)
  end

  config.around(:each) do |example|
    DatabaseCleaner.cleaning { example.run }
  end

  config.expect_with(:rspec) { |c| c.syntax = :expect }
end
