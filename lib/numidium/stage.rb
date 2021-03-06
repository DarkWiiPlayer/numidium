# -- vim: set noexpandtab foldmarker==begin,=end :miv --

=begin Diagrams
	┌──────────────────────────────────────────┐
	│ Stage                                    │
	├──────────────────────────────────────────┤
	│ + new(test, args): Stage                 │
	│ + evaluate(proc-like*): array            │
	│ - assert(reason:string, block): boolean  │
	│ - fail(reason: string): false            │
	│ - pass(reason: string): true             │
	│ - skip(reason: string): nil              │
	│ - test(:Test): boolean                   │
	│ - try(:Test): boolean                    │
	├──────────────────────────────────────────┤
	│ + success: boolean                       │
	│ + events: array                          │
	└──────────────────────────────────────────┘

	┌──────────────────────────────┐
	│ *proc-like means any object  │
	│ that responds to :call       │
	└──────────────────────────────┘
=end

require_relative "result"
require 'fiber'
module Numidium
	class Stage # Provides a fresh environment every time the test is executed
		def success
			if not @success.nil?
				@success
			else
				raise "Cannot inquire the success of an unused stage"
			end
		end
		def events
			if not @events.nil?
				@events
			else
				raise "Cannot inquire the events of an unused stage"
			end
		end

		def initialize(args=[])
			@args = args.freeze
		end

		def evaluate(play)
			@events = []
			@success = []
			thread = Fiber.new do
				instance_exec(*@args, &play)
			rescue Exception => e
				Fiber.yield(Result.new(e))
			end

			loop do
				res = thread.resume(*@args)
				if res.is_a? Numidium::Result or res.is_a? Numidium::Report
					@events << res
				else
					break
				end
			end
			return @events
		end

		private

		class GivenFalse
			def initialize(args) @args=args; end
			def binding() binding; end

			def skip(description)
				Fiber.yield(Result.new(sprintf(description, *@args), :skip).delegate)
				return nil
			end
			alias :pass :skip
			alias :fail :skip
			alias :assert :skip

			def given(reason=nil)
				yield
			end
		end

		def assert(description="Assertion")
			if (yield)
				Fiber.yield(Result.new(sprintf(description, *@args), true).delegate)
				return true
			else
				Fiber.yield(Result.new(sprintf(description, *@args), false).delegate)
				return false
			end
		end

		def skip(description="Unimplemented Test")
			Fiber.yield(Result.new(sprintf(description, *@args), :skip).delegate)
		end

		def given(condition, &block)
			if condition
				block.call
			else
				GivenFalse.new(@args).instance_exec(&block)
			end
		end

		def test(test, *args)
			res = test.run(*args)
			Fiber.yield(res)
			@success &&= res.success
			res.success
		end

		def try(test, *args)
			res = test.try(*args)
			Fiber.yield(res)
			@success &&= res.success
			res.success
		end
	end
end
