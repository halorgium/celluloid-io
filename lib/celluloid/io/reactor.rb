require 'pry'
require 'nio'

module Celluloid
  module IO
    # React to external I/O events. This is kinda sorta supposed to resemble the
    # Reactor design pattern.
    class Reactor
      extend Forwardable

      # Unblock the reactor (i.e. to signal it from another thread)
      def_delegator :@selector, :wakeup

      def initialize(mailbox)
        @mailbox  = mailbox
        @selector = NIO::Selector.new
      end

      def register(thread)
        #binding.pry
        thread[:celluloid_io_reactor] = self
        #binding.pry
      end

      # Wait for the given IO object to become readable
      def wait_readable(io)
        wait io, :r
      end

      # Wait for the given IO object to become writable
      def wait_writable(io)
        wait io, :w
      end

      # Wait for the given IO operation to complete
      def wait(io, set)
        # zomg ugly type conversion :(
        unless io.is_a?(::IO) or io.is_a?(OpenSSL::SSL::SSLSocket)
          if io.respond_to? :to_io
            io = io.to_io
          elsif ::IO.respond_to? :try_convert
            io = ::IO.try_convert(io)
          end

          raise TypeError, "can't convert #{io.class} into IO" unless io.is_a?(::IO)
        end

        Celluloid.logger.info "#{Thread.current.inspect}: waiting for io: #{io.inspect}: #{set.inspect}\n#{caller.join("\t\n")}"
        monitor = @selector.register(io, set)
        monitor.value = Task.current
        binding.pry
        Task.suspend :iowait
      end

      # Run the reactor, waiting for events or wakeup signal
      def run_once(timeout = nil, &block)
        Celluloid.logger.info "running reactor with timeout: #{timeout.inspect}"
        handled = @selector.select(timeout) do |monitor|
          task = monitor.value
          monitor.close

          if task.running?
            task.resume
          else
            Logger.warn("reactor attempted to resume a dead task")
          end
        end

        Logger.info "mailbox size: #{@mailbox.size}"
        # woken up by mailbox
        unless handled || timeout
          Logger.info "woken up by mailbox"
        end
          while @mailbox.size > 0
            yield @mailbox.receive
          end
        #end
      end

      # Terminate the reactor
      def shutdown
        @selector.close
        @mailbox.shutdown
      end
    end
  end
end
