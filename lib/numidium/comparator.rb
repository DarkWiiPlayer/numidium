# -- vim: set noexpandtab foldmarker==begin,=end :miv --
require "benchmark"

module Numidium
  class Comparator
    def initialize(method=:real, &block)
      @method = method
			@block  = block
			@reference = Benchmark::measure(&@block).send(@method)
    end

		def retry()
			self.class.new(&@block)
		end

    def compare(&block)
      Benchmark::measure(&block).send(@method) / @reference
    end
  end
end
