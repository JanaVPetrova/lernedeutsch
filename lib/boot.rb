require 'dotenv/load'
require 'active_record'
require 'yaml'
require 'erb'
require_relative 'msgs'

env = ENV['RACK_ENV'] || 'development'
config = YAML.safe_load(ERB.new(File.read(File.join(__dir__, '..', 'config', 'database.yml'))).result, aliases: true)
ActiveRecord::Base.establish_connection(config[env])
ActiveRecord::Base.logger = Logger.new($stdout) if env == 'development'

require_relative 'models/user'
require_relative 'models/word_group'
require_relative 'models/word'
require_relative 'models/word_review'
require_relative 'models/reminder'

require_relative 'services/answer_scorer'
require_relative 'services/spaced_repetition'
require_relative 'services/word_importer'
require_relative 'services/reminder_scheduler'

require_relative 'handlers/learning_handler'
