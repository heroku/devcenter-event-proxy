require 'bundler/setup'
Bundler.require

STDOUT.sync = true

require './lib/managers/log_manager'
require './lib/parsers/devcenter_message_parser'
require './lib/processors/event_manager_proxy'

LOG_MANAGER = LogManager.new(DevcenterMessageParser, EventManagerProxy)