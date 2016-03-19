module Messages
  class MiddleMan

    def initialize
      @queue = Queue.new
      @ctx = ZMQ::Context.new
    end

    # Pushes a job into the work queue.
    def add_job(message)
      @queue.push(message)
    end

    # Method takes care of starting the work queue.
    def start
      addresses = @startup_socket.recv
      @startup_socket.close
      @job_socket = @ctx.bind(:PUSH, "tcp://*:#{JOB_PORT}")
      work_loop
      JSON.parse(addresses).to_set
    end

    # Method takes care of stopping the work queue.
    def stop
      @worker[:should_halt] = true
      @queue.push(nil)
      @worker.join rescue nil
      @queue.clear
      @socket.close
    end

    # Returns whether or not the MiddleMan is currently running.
    def working?
      return false unless @worker.exists?
      @worker.alive?
    end

    private

    # Actually does the "heavy lifting" of the MiddleMan.
    def work_loop
      @worker = Thread.new do
        loop do
          break if Thread.current[:should_halt]

          # Block until we receive a job. Stop method pushes nil into the
          # queue, so we need to make sure that the job actually exists.
          job = @queue.pop
          socket.send(job.to_json) if job.exists?
        end
      end
    end

  end
end
