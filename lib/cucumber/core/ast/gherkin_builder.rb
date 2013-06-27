require 'cucumber/initializer'
require 'cucumber/core/ast'
require 'cucumber/core/platform'
require 'gherkin/rubify'

module Cucumber
  module Core
    module Ast
      # Builds an AST of a feature by listening to events from the
      # Gherkin parser.
      class GherkinBuilder

        def initialize(path = 'UNKNOWN-FILE')
          @path = path
        end

        def result
          return nil unless @feature_builder
          @feature_builder.result(language)
        end

        def language=(language)
          @language = language
        end

        def uri(uri)
          @path = uri
        end

        def feature(node)
          @feature_builder = FeatureBuilder.new(file, node)
        end

        def background(node)
          builder = BackgroundBuilder.new(file, node)
          @feature_builder.background_builder = builder
          @current = builder
        end

        def scenario(node)
          builder = ScenarioBuilder.new(file, node)
          @feature_builder.add_child builder
          @current = builder
        end

        def scenario_outline(node)
          builder = ScenarioOutlineBuilder.new(file, node)
          @feature_builder.add_child builder
          @current = builder
        end

        def examples(node)
          @current.add_examples file, node
        end

        def step(node)
          @current.add_step file, node
        end

        def eof
        end

        def syntax_error(state, event, legal_events, line)
          # raise "SYNTAX ERROR"
        end

        private

        if defined?(JRUBY_VERSION)
          java_import java.util.ArrayList
          ArrayList.__persistent__ = true
        end

        def language
          @language || raise("Language has not been set")
        end

        def file
          if Cucumber::WINDOWS && !ENV['CUCUMBER_FORWARD_SLASH_PATHS']
            @path.gsub(/\//, '\\')
          else
            @path
          end
        end

        class Builder
          include Cucumber.initializer(:file, :node)

          private

          def tags
            Tags.new(nil, node.tags)
          end

          def location
            Location.new(file, node.line)
          end

          def comment
            Comment.new(node.comments.map{ |comment| comment.value }.join("\n"))
          end
        end

        class FeatureBuilder < Builder
          attr_accessor :background_builder
          private :background_builder

          def initialize(*)
            super
            @background_builder = nil
          end

          def result(language)
            background = background(language)
            feature = Feature.new(
              location,
              background,
              comment,
              tags,
              node.keyword,
              node.name.lstrip,
              node.description.rstrip,
              children.map { |builder| builder.result(background, language, tags) }
            )
            feature.gherkin_statement(node)
            feature.language = language
            feature
          end

          def add_child(child)
            children << child
          end

          def children
            @children ||= []
          end

          private

          def background(language)
            return EmptyBackground.new unless background_builder
            @background ||= background_builder.result(language)
          end
        end

        class BackgroundBuilder < Builder
          def result(language)
            background = Background.new(
              language,
              location,
              comment,
              node.keyword,
              node.name,
              node.description,
              steps(language)
            )
            background.gherkin_statement(node)
            background
          end

          def add_step(file, node)
            step_builders << ScenarioBuilder::StepBuilder.new(file, node)
          end

          private

          def steps(language)
            step_builders.map { |step_builder| step_builder.result(language) }
          end

          def step_builders
            @step_builders ||= []
          end

        end

        class ScenarioBuilder < Builder
          def result(background, language, feature_tags)
            scenario = Scenario.new(
              language,
              location,
              background,
              comment,
              tags,
              feature_tags,
              node.keyword,
              node.name,
              node.description,
              steps(language)
            )
            scenario.gherkin_statement(node)
            scenario
          end

          def add_step(file, node)
            step_builders << StepBuilder.new(file, node)
          end

          private

          def steps(language)
            step_builders.map { |step_builder| step_builder.result(language) }
          end

          def step_builders
            @step_builders ||= []
          end

          class StepBuilder < Builder
            def result(language)
              step = Step.new(
                language,
                location,
                node.keyword,
                node.name,
                MultilineArgument.from(node.doc_string || node.rows)
              )
              step.gherkin_statement(node)
              step
            end
          end
        end

        class ScenarioOutlineBuilder < Builder
          def result(background, language, feature_tags)
            scenario_outline = ScenarioOutline.new(
              language,
              location,
              background,
              comment,
              tags,
              feature_tags,
              node.keyword,
              node.name,
              node.description,
              steps(language),
              examples_tables
            )
            scenario_outline.gherkin_statement(node)
            scenario_outline
          end

          def add_examples(file, node)
            examples_tables << ExamplesTableBuilder.new(file, node).result
          end

          def add_step(file, node)
            step_builders << StepBuilder.new(file, node)
          end

          private

          def steps(language)
            step_builders.map { |step_builder| step_builder.result(language) }
          end

          def step_builders
            @step_builders ||= []
          end

          def examples_tables
            @examples_tables ||= []
          end

          class ExamplesTableBuilder < Builder
            include Gherkin::Rubify

            def result
              ExamplesTable.new(
                location,
                comment,
                node.keyword,
                node.name,
                node.description,
                header,
                example_rows
              )
            end

            private

            def header
              row = node.rows[0]
              ExamplesTable::Header.new(row.cells)
            end

            def example_rows
              rubify(node.rows)[1..-1].map do |row|
                header.build_row(row.cells)
              end
            end
          end

          class StepBuilder < Builder
            def result(language)
              step = OutlineStep.new(
                language,
                location,
                node.keyword,
                node.name,
                MultilineArgument.from(node.doc_string || node.rows)
              )
              step.gherkin_statement(node)
              step
            end
          end
        end

      end
    end
  end
end
