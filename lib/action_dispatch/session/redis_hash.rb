class ActionDispatch::Session::RedisHash < ActionDispatch::Session::AbstractStore
  include ::Redis::RedisHashSession
end

