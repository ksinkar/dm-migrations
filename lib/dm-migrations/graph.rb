require 'dm-migrations/exceptions/duplicate_migration'
require 'dm-migrations/exceptions/unknown_migration'
require 'dm-migrations/migration'

require 'set'
require 'tsort'

module DataMapper
  module Migrations
    class Graph
      include Enumerable
      include TSort

      # The migrations in the graph
      attr_reader :migrations

      #
      # Creates a new Migration Graph.
      #
      # @since 1.0.1
      #
      def initialize
        @migrations = {}
        @positions  = {}
      end

      #
      # @api private
      #
      def tsort_each_node(&block)
        @migrations.each_key(&block)
      end

      #
      # @api private
      #
      def tsort_each_child(node)
        unless @migrations.has_key?(node)
          raise(RuntimeError, "no migration defined for #{node}", caller)
        end

        @migrations[node].needs.each do |dep|
          yield name_of(dep)
        end
      end

      #
      # Defines a migration.
      #
      # @param [Symbol] name
      #   The name of the migration.
      #
      # @param [Hash] options
      #   Additional options for the migration.
      #
      # @option options [Boolean] :verbose (true)
      #   Enables or disables verbose output.
      #
      # @option options [Symbol] :repository (:default)
      #   The DataMapper repository the migration will operate on.
      #
      # @option options [Array, Symbol] :needs
      #   Other migrations that are dependencies of the migration.
      #
      # @return [Migration]
      #   The newly defined migration.
      #
      # @raise [DuplicateMigration]
      #   Another migration was previously defined with the same name.
      #
      # @since 1.0.1
      #
      # @api semipublic
      #
      def migration_named(name, options = {}, &block)
        if @migrations.has_key?(name)
          raise(DuplicateMigration, "there is already a migration with the name #{name}", caller)
        end

        @migrations[name] = Migration.new(name, options, &block)
      end

      #
      # Defines a migration assigned to a given position.
      #
      # @param [Integer] position
      #   The position of the migration.
      #
      # @param [Symbol] name
      #   The name of the migration.
      #
      # @param [Hash] options
      #   Additional options for the migration.
      #
      # @return [Migration]
      #   The newly defined migration.
      #
      # @raise [DuplicateMigration]
      #   Another migration was previously defined with the same name or
      #   position.
      #
      # @see migration_named
      #
      # @since 1.0.1
      #
      # @api semipublic
      #
      def migration_at(position, name, options = {}, &block)
        if @positions.has_key?(position)
          raise(DuplicateMigration, "there is already a migration at position #{position}", caller)
        end

        # define a mapping from position to migration name
        @positions[position] = name

        if position > 1
          # explicit define a dependencey on the previous migration position
          options[:needs] = [position - 1]
        end

        migration_named(name, options, &block)
      end

      #
      # Enumerates over the migrations up to a specific migration.
      #
      # @param [Integer, Symbol, nil] position_or_name
      #   The migration position or name to stop after.
      #
      # @yield [migration]
      #   The given block will be passed each migration. Once the migration
      #   of the given position or name is yielded, no further migrations
      #   will be yielded.
      #
      # @yieldparam [Migration] migration
      #   A migration from the graph.
      #
      # @return [Enumerator]
      #   If no block is given, an enumerator object will be returned.
      #
      # @raise [UnknownMigration]
      #   A migration had a dependencey on an unknown migration.
      #
      # @since 1.0.1
      #
      # @api semipublic
      #
      def up_to(position_or_name = nil)
        return enum_for(:up_to, position_or_name) unless block_given?

        name = name_of(position_or_name)

        # tsort named migrations by their dependencies
        tsort.each do |key|
          yield @migrations[key]

          # break after the target migration has been reached
          break if (name && name == key)
        end
      end

      #
      # Enumerates over the migrations down to a specific migration.
      #
      # @param [Integer, Symbol, nil] position_or_name
      #   The migration position or name to stop before.
      #
      # @yield [migration]
      #   The given block will be passed each migration. Once the migration
      #   of the given position or name is reached, no further migrations
      #   will be yielded.
      #
      # @yieldparam [Migration] migration
      #   A migration from the graph.
      #
      # @return [Enumerator]
      #   If no block is given, an enumerator object will be returned.
      #
      # @raise [UnknownMigration]
      #   A migration had a dependencey on an unknown migration.
      #
      # @since 1.0.1
      #
      # @api semipublic
      #
      def down_to(position_or_name = nil)
        return enum_for(:down_to, position_or_name) unless block_given?

        name = name_of(position_or_name)

        # tsort named migrations by their dependencies
        tsort.reverse_each do |key|
          # break before the target migration is reached
          break if (name && name == key)

          yield @migrations[key]
        end
      end

      protected

      #
      # Maps a position or name to a migration name.
      #
      # @param [Symbol, Integer] position_or_name
      #   The migration position or name.
      #
      # @return [Symbol]
      #   The migration name.
      #
      # @raise [UnknownMigration]
      #   There was no migration defined at the given position.
      #
      # @since 1.0.1
      #
      # @api private
      #
      def name_of(position_or_name)
        case position_or_name
        when Integer
          unless @positions.has_key?(position_or_name)
            raise(UnknownMigration, "unknown migration position #{position_or_name}", caller)
          end

          @positions[position_or_name]
        when Symbol
          position_or_name
        end
      end

    end
  end
end
