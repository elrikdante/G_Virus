module G_Virus

  def self.included(base)
    base.extend(ClassMethods)
    base.redis = Resque.redis
  end

  module ClassMethods
    attr_accessor :key , :redis

    def dead_jobs
      @redis.hgetall(key)
    end

    def ressurect_job(job)
      @redis.hset(key,job, 3) if infection_level(job).nil?
    end

    def key
        @key ||= [self.name,:dead].join('-')
    end

    def infection_level(job)
      @redis.hget(key, job).tap{ |infection| infection.presence ? infection.to_i : nil}
    end

    def kill_job(job)
      @redis.hdel(key,job)
    end

    def kill_jobs
      @redis.del(key)
    end

    def apply_virus(job)
        @redis.hincrby(key ,job, -1)
    end

    def after_perform(*args)
      args = args.shift
      event = args.delete('event')
      job_identifier = [event, *(args.keys), args['id']].join('-')
      kill_job(job_identifier)
    end

    def on_failure_infect(exception, *args)
      args = args.shift
      event = args.delete('event')
      job_identifier = [event, *(args.keys), args['id']].join('-')
      ressurect_job(job_identifier)
      apply_virus(job_identifier)
      if(infection_level(job_identifier) > 0)
        sleep(2)
        Resque.enqueue self,args.update('event' => event)
      else
        kill_job(job_identifier)
      end
    end
  end
end
