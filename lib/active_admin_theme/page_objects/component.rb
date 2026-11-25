module ActiveAdminTheme
  module PageObjects
    # Base class of the sections for the theme's components. A component can
    # sit anywhere, so besides a `section` declaration it is found inside any
    # scope: a page, a section or a Capybara node such as a table cell.
    #
    #   StatusTag.find_in(index.table.row(1).cell(:status)).kind
    #   SecretReveal.find_in(show.attributes_table.row(:token)).reveal
    class Component < ActiveAdminPageObjects::Section
      class << self
        # The component inside +scope+. Takes Capybara's find options.
        def find_in(scope, **options)
          new(scope, scope.find(*default_search_arguments, **options))
        end

        # Every such component inside +scope+, in document order.
        # @return [Array<Component>]
        def all_in(scope, **options)
          scope.all(*default_search_arguments, **options).map { |node| new(scope, node) }
        end
      end
    end
  end
end
