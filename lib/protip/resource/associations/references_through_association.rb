require 'active_support/core_ext/string/inflections' # For classifying/constantizing strings

require 'protip/resource/associations/reference'

module Protip
  module Resource
    module Associations
      class ReferencesThroughAssociation

        include Protip::Resource::Associations::Reference

        attr_reader :resource_class, :reference_name, :reference_class

        def initialize(resource_class, id_field, reference_name: nil, class_name: nil)
          # The resource type that houses the association
          @resource_class = resource_class

          # The field that holds the ID for the association
          @id_field = id_field.to_sym

          # The name for generating accessor methods
          @reference_name = (
            reference_name || Protip::Resource::Associations::Reference.default_reference_name(id_field)
          ).to_sym

          # The resource type that we're pointing to
          @reference_class = (class_name || default_class_name(@id_field)).constantize
        end

        def read(resource)
          id = resource.public_send(@id_field)
          if id == nil
            nil
          else
            @reference_class.find id
          end
        end

        def write(resource, value)
          # TODO: error if a value with an empty ID is passed in?
          resource.public_send(:"#{@id_field}=", value.try(:id))
        end

        class << self
          def default_class_name(id_field)
            Protip::Resource::Associations::Reference.default_reference_name(id_field).classify
          end
        end
      end
    end
  end
end