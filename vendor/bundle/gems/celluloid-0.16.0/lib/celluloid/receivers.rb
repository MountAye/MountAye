require 'set'

require 'timers'

module Celluloid
  # Allow methods to directly interact with the actor protocol
  class Receivers
    def initialize(timers)
      @receivers = Set.new
      @timers = timers
    end

    # Receive an asynchronous message
    def receive(timeout = nil, &block)
      if Celluloid.exclusive?
        Celluloid.mailbox.receive(timeout, &block)
      else
        receiver = Receiver.new block

        if timeout
          receiver.timer = @timers.after(timeout) do
            @receivers.delete receiver
            receiver.resume
          end
        end

        @receivers << receiver
        Task.suspend :receiving
      end
    end

    # Handle incoming messages
    def handle_message(message)
      receiver = @receivers.find { |r| r.match(message) }
      return unless receiver

      @receivers.delete receiver
      receiver.timer.cancel if receiver.timer
      receiver.resume message
      message
    end
  end

  # Methods blocking on a call to receive
  class Receiver
    attr_accessor :timer

    def initialize(block)
      @block = block
      @task  = Task.current
      @timer = nil
    end

    # Match a message with this receiver's block
    def match(message)
      @block ? @block.call(message) : true
    end

    def resume(message = nil)
      @task.resume message
    end
  end
end
