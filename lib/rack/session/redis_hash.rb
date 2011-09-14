module Redis::RedisHashSession

  def initialize(app, options = {})
    super
    @expire_after = options[:expire_after] || 60*60 # 60 minutes, default
  end

  def get_session(env, sid)
    session = Redis::LazyHash.new session_prefix => sid
    sid = session.key
    return [sid, session]
  end

  def set_session(env, session_id, session, options)
    @expire_after = options[:expire_after] || @expire_after
    unless session.kind_of?(Redis::LazyHash)
      real_session = Redis::LazyHash.new(session_prefix)
      real_session.update(session) if session.kind_of?(Hash)
      real_session.key = session_id unless session_id.nil?
      session = real_session
    end
    if options[:drop]
      session.destroy
      return false if options[:drop]
    end
    if options[:renew]
      session_id = session.renew_key
    end
    session.save
    session.expire @expire_after
    return session_id
  end

  def destroy_session(env, sid, options)
    session = Redis::LazyHash.new( session_prefix => sid )
    unless session.nil?
      options[:renew] ? session.renew_key : session.destroy
      session.key
    end
  end

  def session_prefix
    :rack_session
  end
end

module Rack
  module Session
    module Abstract
      class ID
        # overwrite prepare_session behavior to turn off use of SessionHash
        def prepare_session(env)
          session_was                  = env[ENV_SESSION_KEY]
          env[ENV_SESSION_OPTIONS_KEY] = OptionsHash.new(self, env, @default_options)
          env[ENV_SESSION_OPTIONS_KEY][:id], env[ENV_SESSION_KEY] = load_session(env)
          env[ENV_SESSION_KEY].merge! session_was if session_was
        end
      end
    end
  end
end

module Rack
  module Session
    class RedisHash < Abstract::ID
      include ::Redis::RedisHashSession
    end
  end
end