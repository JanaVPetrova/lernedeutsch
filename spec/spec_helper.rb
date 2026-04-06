require 'dotenv'
Dotenv.load('.env.test', '.env')

ENV['RACK_ENV'] = 'test'

require 'active_record'
require 'telegram/bot'
require 'factory_bot'
require 'pry-byebug'
require 'database_cleaner/active_record'

# Database setup
require 'yaml'
require 'erb'
config = YAML.safe_load(ERB.new(File.read(File.join(__dir__, '..', 'config', 'database.yml'))).result, aliases: true)
ActiveRecord::Base.establish_connection(config['test'])

# msgs.rb must load before handlers because LearningHandler::LEARNING_KEYBOARD
# references MSGS at class-load time.
require_relative '../lib/msgs'

# Load models, services, and handlers
Dir[File.join(__dir__, '..', 'lib', 'models',   '*.rb')].each { |f| require f }
Dir[File.join(__dir__, '..', 'lib', 'services', '*.rb')].each { |f| require f }
Dir[File.join(__dir__, '..', 'lib', 'handlers', '*.rb')].each { |f| require f }

# Stub top-level constants that bot.rb defines at startup
MAIN_KEYBOARD = :main_keyboard_stub unless defined?(MAIN_KEYBOARD)

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
