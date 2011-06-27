module Rack
  module Session
    class RedisHash < Abstract::ID

      def get_session(env, sid)
        session = ::RedisHash.find session_prefix => sid
        unless sid and session
          env['rack.errors'].puts("Session '#{sid.inspect}' not found, initializing...") if $VERBOSE and not sid.nil?
          session = ::RedisHash.new session_prefix
          sid = session.key
        end
        return [sid, session]
      end

      def set_session(env, session_id, session, options)
        if options[:renew] or options[:drop]
          session.destroy
          return false if options[:drop]
          session_id = session.key
        end
        if session.kind_of?(::RedisHash)
          session.save
        elsif session.kind_of?(Hash)
          final_hash = ::RedisHash.new session_prefix
          final_hash.update?(new_session)
          final_hash.save
          session_id = final_hash.key
        end
        return session_id
      end

      def session_prefix
        :rack_session
      end

    end
  end
end

