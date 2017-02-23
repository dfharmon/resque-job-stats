module Resque
  module Plugins
    module JobStats

      # Extend your job with this module to track how many
      # jobs are queued successfully
      module WaitTime

        # Resets all wait durations
        def reset_wait_durations
          Resque.redis.del(wait_duration_key)
        end

        # Returns the wait durations
        def wait_durations
          Resque.redis.lrange(wait_duration_key,0,waits_recorded - 1).map(&:to_f)
        end

        # Returns the key used for tracking wait times
        def wait_duration_key
          "stats:jobs:#{self.name}:wait"
        end

        def waits_recorded
          @waits_recorded || 100
        end

        def wait_rolling_avg
          wait_times = wait_durations
          return 0.0 if wait_times.size == 0.0
          wait_times.inject(0.0) {|s,j| s + j} / wait_times.size
        end

        def longest_wait
          wait_durations.max.to_f
        end

      end
    end
  end

  class Job
    alias_method :perform_without_lifecyle, :perform

    def perform
      begin
        if Resque::Plugins::JobStats.measured_jobs.include?(self.payload_class) && self.payload_class.methods.include?(:wait_duration_key) && self.payload['created_at']
          wait = Time.now.to_i - self.payload['created_at'].to_i
          Resque.redis.lpush(self.payload_class.wait_duration_key, wait)
          Resque.redis.ltrim(self.payload_class.wait_duration_key, 0, self.payload_class.waits_recorded)
        end
      rescue
      end
      self.perform_without_lifecyle
    end
  end

end



