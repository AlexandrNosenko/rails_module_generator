# frozen_string_literal: true

# TODO: Misc
#   * Add relations descriptors generator integration.erb
#   * add more features to specs
#
require_relative './helpers/generator_helpers'
require_relative './helpers/controller_generator_helper'
require_relative './helpers/service_generator_helper'
require_relative './helpers/policy_generator_helper'
require_relative './helpers/serializer_generator_helper'
require_relative './helpers/service_spec_generator_helper'
require_relative './helpers/integration_spec_generator_helper'
require_relative './helpers/spec_descriptor_generator_helper'
require_relative './helpers/policy_spec_generator_helper'
require_relative './helpers/serializer_spec_generator_helper'

class ModuleScaffoldGenerator < Rails::Generators::NamedBase
  source_root File.expand_path('templates', __dir__)

  class_option :'routes-namespace', type: :string, default: '', desc: 'Routes namespace'
  class_option :'controller-actions', type: :array, default: ControllerGeneratorHelper.new(nil).actions, desc: 'Desired controller & service actions'
  class_option :only, type: :array, default: [], desc: 'Runs only specified generators'
  class_option :except, type: :array, default: [], desc: 'Does not run specified generators'
  class_option :'skip-routes', type: :boolean, default: false, desc: 'Skips route generation'

  desc 'Generates service oriented CRUD scaffold for an existing Model'

  include GeneratorHelpers

  def initialize_helpers
    begin
      name.constantize
    rescue StandardError
      raise "Model #{name} is not defined"
    end

    @controller_helper = ControllerGeneratorHelper.new(name, options)
    @policy_helper = PolicyGeneratorHelper.new(name)
    @services_helper = ServiceGeneratorHelper.new(name, options)
    @serializer_helper = SerializerGeneratorHelper.new(name)
    @services_specs_helper = ServiceSpecGeneratorHelper.new(name, options)
    @integration_spec_helper = IntegrationSpecGeneratorHelper.new(name, options)
    @descriptor_spec_helper = SpecDescriptorGeneratorHelper.new(name)
    @policy_spec_helper = PolicySpecGeneratorHelper.new(name, options)
    @serializer_spec_helper = SerializerSpecGeneratorHelper.new(name)
  end

  def run_generators
    required_generators.each do |generator_name|
      generator_helper = instance_variable_get("@#{generator_name}_helper")

      create_files_from_template(generator_helper)
    end
  end

  def add_routes
    return if options[:'skip-routes'].present?

    route_string = mc_wrap_route_with_namespaces(@controller_helper.namespace) do
      actions = @controller_helper
                .actions
                .map { |attr| ":#{attr}" }
                .join(', ')

      "resources :#{@controller_helper.resource_name_plural}, only: [#{actions}]"
    end

    route route_string
  end

  private

  def required_generators
    %w[
      controller
      policy
      serializer
      services
      descriptor_spec
      integration_spec
      policy_spec
      services_specs
      serializer_spec
    ].tap do |default_generators|
      if options[:except].present?
        default_generators.reject! { |g| options[:except].include?(g) }
      elsif  options[:only].present?
        default_generators.select! { |g| options[:only].include?(g) }
      end
    end
  end

  def create_files_from_template(helper)
    helper.versions.map do |version|
      template(
        helper.template_path(version),
        helper.class_file_path(version)
      )
    end
  end
end
