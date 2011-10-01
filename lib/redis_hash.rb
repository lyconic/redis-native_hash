require 'redis'
require 'core_ext/hash' unless defined?(ActiveSupport)
require 'redis/marshal'
require 'redis/tracked_hash'
require 'redis/client_helper'
require 'redis/key_helper'
require 'redis/big_hash'
require 'redis/native_hash'
require 'redis/lazy_hash'

if defined?(Rack::Session)
  require "rack/session/abstract/id"
  require 'rack/session/redis_hash'
end

if defined?(ActionDispatch::Session)
  require 'action_dispatch/session/redis_hash'
end

if defined?(ActiveSupport)
  require "active_support/cache/redis_store"
end