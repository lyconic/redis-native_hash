require 'redis'
require 'redis/marshal'
require 'core_ext/hash'
require 'tracked_hash'
require 'redis_hash'
if defined?(Rack::Session)
  require "rack/session/abstract/id"
  require 'rack/session/redis_hash'
end

