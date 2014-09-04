require 'cucumber/core/ast/location'
require 'cucumber/core/ast/describes_itself'
require 'cucumber/core/ast/step'

module Cucumber
  module Core
    module Ast

      class OutlineStep
        include HasLocation
        include DescribesItself

        attr_reader :gherkin_statement, :language, :location, :keyword, :name, :multiline_arg

        def initialize(gherkin_statement, language, location, keyword, name, multiline_arg)
          @gherkin_statement, @language, @location, @keyword, @name, @multiline_arg = gherkin_statement, language, location, keyword, name, multiline_arg
          @language || raise("Language is required!")
        end

        def to_step(row)
          Ast::Step.new(self, language, row.location, keyword, row.expand(name), replace_multiline_arg(row))
        end

        private

        def description_for_visitors
          :outline_step
        end

        def children
          # TODO remove duplication with Step
          # TODO spec
          [@multiline_arg]
        end

        def replace_multiline_arg(example_row)
          return unless multiline_arg
          multiline_arg.map { |cell| example_row.expand(cell) }
        end
      end

    end
  end
end

